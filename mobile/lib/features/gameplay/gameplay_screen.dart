import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/attempt.dart';
import '../../models/session.dart';
import '../../services/game_repository.dart';
import '../../services/text_to_speech_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/gameplay_widgets.dart';
import '../../widgets/read_aloud_button.dart';
import '../../widgets/state_views.dart';

/// M-13 Gameplay (design-spec §1D, §21).
///
/// Server-authoritative throughout: the attempt is opened server-side, each
/// answer is a separate validated request, and the score is never computed here.
/// The countdown is per question and resets on every question, matching the
/// backend's per-answer time ceiling.
class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.args});

  final GameplayArgs args;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  static const Duration _feedbackPause = Duration(milliseconds: 550);

  StartedAttempt? _attempt;
  int _index = 0;
  int _secondsRemaining = 0;
  Timer? _ticker;
  final Stopwatch _questionClock = Stopwatch();

  bool _starting = true;
  bool _submitting = false;
  String? _startError;
  bool _startOffline = false;
  String? _inlineNotice;
  int? _selectedIndex;
  bool? _selectedCorrect;

  /// Kept so an offline submit can be retried with the same payload rather than
  /// forcing the player to re-answer a question they already answered.
  _PendingAnswer? _pending;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    context.read<TextToSpeechService>().stop();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
      _startOffline = false;
    });

    try {
      final StartedAttempt attempt = await context
          .read<GameRepository>()
          .startAttempt(widget.args.level.levelNumber);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _starting = false;
        _index = 0;
      });
      _beginQuestion();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startOffline = error.isOffline;
        _startError = error.message;
      });
    }
  }

  void _beginQuestion() {
    final StartedAttempt? attempt = _attempt;
    if (attempt == null) return;

    _ticker?.cancel();
    setState(() {
      _secondsRemaining = attempt.timerSeconds;
      _selectedIndex = null;
      _selectedCorrect = null;
      _inlineNotice = null;
    });
    _questionClock
      ..reset()
      ..start();

    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      final int next = _secondsRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        _handleTimerExpired();
        return;
      }
      setState(() => _secondsRemaining = next);
    });

    // design-spec §8 requires the position to be announced on every transition.
    // The prompt and options are announced by the screen reader traversing the
    // rebuilt subtree; the position is not focusable, so it needs this.
    SemanticsService.announce(
      AppLocalizations.of(context)
          .gameplayProgress(_index + 1, attempt.questions.length),
      Directionality.of(context),
    );
  }

  Future<void> _answer(int optionIndex) async {
    if (_submitting || _selectedIndex != null) return;
    final StartedAttempt? attempt = _attempt;
    if (attempt == null) return;

    _questionClock.stop();
    final int elapsedMs = _questionClock.elapsedMilliseconds;

    // Below the server's plausibility floor the attempt would be flagged
    // suspicious and discarded, so the tap is refused here instead — the player
    // keeps their attempt and simply answers again.
    if (elapsedMs < AppConfig.answerTimeFloorMs) {
      setState(() => _inlineNotice = AppLocalizations.of(context).gameplayTooFast);
      _questionClock.start();
      return;
    }

    _ticker?.cancel();
    await _submit(_PendingAnswer(
      questionIndex: _index,
      optionIndex: optionIndex,
      elapsedMs: elapsedMs,
    ));
  }

  Future<void> _submit(_PendingAnswer answer) async {
    final StartedAttempt? attempt = _attempt;
    if (attempt == null) return;

    setState(() {
      _submitting = true;
      _pending = answer;
      _selectedIndex = answer.optionIndex;
      _inlineNotice = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final GameRepository game = context.read<GameRepository>();

    try {
      final AnswerResult result = await game.submitAnswer(
        attemptId: attempt.attemptId,
        questionIndex: answer.questionIndex,
        selectedOptionIndex: answer.optionIndex,
        clientTimeTakenMs: answer.elapsedMs,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pending = null;
      });
      await _applyResult(result, answer);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isOffline) {
        // design-spec §15 M-13: the attempt is not lost — the answer is held and
        // resent, because only the server can decide whether it was correct.
        setState(() {
          _submitting = false;
          _selectedIndex = null;
          _inlineNotice = l10n.gameplayConnectionLost;
        });
        return;
      }
      if (error.code == 'attempt_not_active') {
        await _resyncOrFail();
        return;
      }
      setState(() {
        _submitting = false;
        _selectedIndex = null;
        _pending = null;
        _inlineNotice = error.message;
      });
    }
  }

  Future<void> _applyResult(AnswerResult result, _PendingAnswer answer) async {
    final StartedAttempt attempt = _attempt!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (!result.accepted) {
      switch (result.rejectionReason) {
        case RejectionReason.sequenceViolation:
          // The client and server disagree about which question is next; the
          // server's index wins.
          setState(() {
            _index = result.expectedNextIndex.clamp(0, attempt.questions.length - 1);
            _selectedIndex = null;
            _inlineNotice = l10n.gameplayAnswerRejected;
          });
          _beginQuestion();
          return;

        case RejectionReason.timeFloor:
        case RejectionReason.timeCeiling:
        case RejectionReason.expired:
          // The attempt is terminal server-side; there is nothing to continue.
          _goToFail(FailReason.wrongAnswer, answer.questionIndex);
          return;

        case RejectionReason.rateLimit:
          setState(() {
            _selectedIndex = null;
            _inlineNotice = l10n.gameplayAnswerRejected;
          });
          _beginQuestion();
          return;

        case null:
          setState(() {
            _selectedIndex = null;
            _inlineNotice = l10n.gameplayAnswerRejected;
          });
          _beginQuestion();
          return;
      }
    }

    setState(() => _selectedCorrect = result.correct);
    SemanticsService.announce(
      result.correct ? l10n.gameplayCorrect : l10n.gameplayWrong,
      Directionality.of(context),
    );
    await Future<void>.delayed(_feedbackPause);
    if (!mounted) return;

    if (result.levelPassed) {
      Navigator.of(context).pushReplacementNamed(
        Routes.levelComplete,
        arguments: LevelCompleteArgs(
          levelNumber: attempt.levelNumber,
          score: result.score,
          attemptNumber: attempt.attemptNumber,
          userRank: result.userRank,
          nextLevelNumber: result.nextLevelNumber,
          nextLevelLocked: result.nextLevelLocked ?? false,
          adEligible: result.adEligible,
          scoreSyncDeferred: false,
        ),
      );
      return;
    }

    if (result.levelFailed) {
      _goToFail(FailReason.wrongAnswer, answer.questionIndex);
      return;
    }

    setState(() => _index = result.expectedNextIndex);
    _beginQuestion();
  }

  Future<void> _handleTimerExpired() async {
    final StartedAttempt? attempt = _attempt;
    if (attempt == null || _submitting) return;
    _questionClock.stop();

    try {
      await context.read<GameRepository>().reportTimerExpired(
            attemptId: attempt.attemptId,
            questionIndex: _index,
          );
    } on ApiException {
      // The attempt expires server-side on its own budget, so a failed report
      // only costs the analytics event — the player still sees M-16.
    }
    if (!mounted) return;
    _goToFail(FailReason.timerExpired, _index);
  }

  /// Recovers from an attempt the server considers finished: ask for its real
  /// state rather than guessing, then route accordingly.
  Future<void> _resyncOrFail() async {
    final StartedAttempt? attempt = _attempt;
    if (attempt == null) return;
    try {
      final AttemptState state =
          await context.read<GameRepository>().attemptState(attempt.attemptId);
      if (!mounted) return;
      if (state.status == AttemptStatus.completed) {
        Navigator.of(context).pushReplacementNamed(
          Routes.levelComplete,
          arguments: LevelCompleteArgs(
            levelNumber: attempt.levelNumber,
            score: state.score,
            attemptNumber: attempt.attemptNumber,
            userRank: null,
            nextLevelNumber: attempt.levelNumber + 1,
            nextLevelLocked: false,
            adEligible: false,
            scoreSyncDeferred: false,
          ),
        );
        return;
      }
      if (state.status == AttemptStatus.inProgress) {
        setState(() {
          _submitting = false;
          _selectedIndex = null;
          _index = state.expectedNextIndex.clamp(0, attempt.questions.length - 1);
        });
        _beginQuestion();
        return;
      }
      _goToFail(FailReason.wrongAnswer, _index);
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedIndex = null;
        _inlineNotice = AppLocalizations.of(context).gameplayConnectionLost;
      });
    }
  }

  void _goToFail(FailReason reason, int questionIndex) {
    _ticker?.cancel();
    final StartedAttempt attempt = _attempt!;
    Navigator.of(context).pushReplacementNamed(
      reason == FailReason.timerExpired ? Routes.timerExpired : Routes.levelFail,
      arguments: LevelFailArgs(
        level: widget.args.level,
        reason: reason,
        attemptNumber: attempt.attemptNumber,
        questionIndexAtFail: questionIndex,
      ),
    );
  }

  Future<bool> _confirmQuit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Resolved before the dialog, not after it: the dialog is an await, and by
    // the time it returns this element may be on its way out.
    final GameRepository game = context.read<GameRepository>();
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.gameplayQuitTitle),
        content: Text(l10n.gameplayQuitBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.gameplayQuitConfirm),
          ),
        ],
      ),
    );

    if (leave != true) return false;

    _ticker?.cancel();
    final StartedAttempt? attempt = _attempt;
    if (attempt != null) {
      try {
        await game.abandonAttempt(attempt.attemptId);
      } on ApiException {
        // Abandoning is bookkeeping; the attempt also expires on its own budget.
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StartedAttempt? attempt = _attempt;

    if (_starting) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.levelDetailTitle(widget.args.level.levelNumber)),
        ),
        body: const LoadingView(),
      );
    }

    if (attempt == null || attempt.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.levelDetailTitle(widget.args.level.levelNumber)),
        ),
        body: _startOffline
            ? ErrorView.offline(context, onRetry: _start)
            : ErrorView(
                title: l10n.errorGenericTitle,
                message: _startError ?? l10n.gameplayLoadFailed,
                onRetry: _start,
                secondaryLabel: l10n.actionBackToMap,
                onSecondary: () => Navigator.of(context).pop(),
              ),
      );
    }

    final AttemptQuestion question =
        attempt.questions[_index.clamp(0, attempt.questions.length - 1)];
    final SessionUser? user = context.watch<SessionController>().user;
    final bool readAloud =
        user?.ageGroup == AgeGroup.kid || user?.ageGroup == AgeGroup.youth;

    // Captured once for both quit paths. The confirm dialog is an await, so
    // reaching for the navigator afterwards is a lookup on an element that may
    // already be gone; the state itself is still the right thing to check.
    final NavigatorState navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _confirmQuit() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.gameplayQuitTitle,
            onPressed: () async {
              if (await _confirmQuit() && mounted) {
                navigator.pop();
              }
            },
          ),
          title: QuestionProgressLabel(
            index: _index + 1,
            total: attempt.questions.length,
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: TimerDisplay(
                secondsRemaining: _secondsRemaining,
                totalSeconds: attempt.timerSeconds,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: Layout.useWideLayout(context) ? 900 : Layout.contentMaxWidth,
              child: AdaptiveTwoPane(
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    QuestionPrompt(
                      variantType: question.variantType,
                      questionText: question.questionText,
                      verseReference: question.verseReference,
                      verseExcerpt: question.verseExcerpt,
                      imageAssetKey: question.imageAssetKey,
                      imageAltText: question.imageAltText,
                    ),
                    if (readAloud) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      ReadAloudButton(
                        text: question.questionText,
                        verseReference: question.verseReference,
                        verseExcerpt: question.verseExcerpt,
                      ),
                    ],
                    if (_inlineNotice != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      NoticeBanner(
                        message: _inlineNotice!,
                        tone: NoticeTone.warning,
                        icon: Icons.wifi_off_rounded,
                        actionLabel: _pending == null ? null : l10n.actionRetry,
                        onAction: _pending == null
                            ? null
                            : () => _submit(_pending!),
                      ),
                    ],
                  ],
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < question.options.length; i++)
                      AnswerOptionButton(
                        label: question.options[i],
                        state: _selectedIndex != i
                            ? AnswerOptionState.idle
                            : _selectedCorrect == null
                                ? AnswerOptionState.idle
                                : _selectedCorrect!
                                    ? AnswerOptionState.correct
                                    : AnswerOptionState.wrong,
                        onPressed: _submitting || _selectedIndex != null
                            ? null
                            : () => _answer(i),
                      ),
                    if (_submitting)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingAnswer {
  const _PendingAnswer({
    required this.questionIndex,
    required this.optionIndex,
    required this.elapsedMs,
  });

  final int questionIndex;
  final int optionIndex;
  final int elapsedMs;
}
