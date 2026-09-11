import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/content_pack.dart';
import '../../models/session.dart';
import '../../services/analytics_service.dart';
import '../../services/content_service.dart';
import '../../services/game_repository.dart';
import '../../services/text_to_speech_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/gameplay_widgets.dart';
import '../../widgets/read_aloud_button.dart';
import '../../widgets/state_views.dart';

/// M-19 Practice gameplay (design-spec §1G, §19).
///
/// Everything is local: questions, option order, and correctness all come from
/// the on-device pack, and no attempt is opened server-side. That is the whole
/// point — practice must work with no network, and it must never be able to
/// influence the leaderboard.
class PracticeGameplayScreen extends StatefulWidget {
  const PracticeGameplayScreen({super.key, required this.args});

  final PracticeGameplayArgs args;

  @override
  State<PracticeGameplayScreen> createState() => _PracticeGameplayScreenState();
}

class _PracticeGameplayScreenState extends State<PracticeGameplayScreen> {
  static const Duration _feedbackPause = Duration(milliseconds: 550);
  static const int _questionsPerAttempt = 10;

  late final List<_PracticeQuestion> _questions;
  late final int _timerSeconds;

  int _index = 0;
  int _correctCount = 0;
  int _secondsRemaining = 0;
  Timer? _ticker;
  final Stopwatch _attemptClock = Stopwatch();

  int? _selectedIndex;
  bool? _selectedCorrect;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final ContentService content = context.read<ContentService>();
    if (!content.isOfflinePracticeLevel(widget.args.levelNumber)) {
      _questions = const <_PracticeQuestion>[];
      _timerSeconds = 30;
      return;
    }
    final PackLevel? level = content.levelFor(widget.args.levelNumber);
    _timerSeconds = level?.timerSeconds ?? 30;
    _questions = _buildSet(content.questionsFor(widget.args.levelNumber));

    context.read<AnalyticsService>().track(
      'practice_level_started',
      properties: <String, Object?>{
        'level_id': widget.args.levelNumber,
        'attempt_number': widget.args.attemptNumber,
      },
    );

    if (_questions.isNotEmpty) {
      _attemptClock.start();
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginQuestion());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    context.read<TextToSpeechService>().stop();
    super.dispose();
  }

  /// Picks up to ten questions and shuffles the four options, mirroring what the
  /// server does for a ranked attempt so practice feels identical.
  List<_PracticeQuestion> _buildSet(List<PackQuestion> pool) {
    if (pool.isEmpty) return const <_PracticeQuestion>[];
    final Random random = Random();
    final List<PackQuestion> shuffled = List<PackQuestion>.of(pool)..shuffle(random);
    final List<PackQuestion> selected =
        shuffled.take(min(_questionsPerAttempt, shuffled.length)).toList();

    return selected.map((PackQuestion question) {
      final List<String> options = List<String>.of(question.answerOptions)
        ..shuffle(random);
      return _PracticeQuestion(
        source: question,
        options: options,
        correctIndex: options.indexOf(question.correctAnswer),
      );
    }).toList();
  }

  void _beginQuestion() {
    _ticker?.cancel();
    setState(() {
      _secondsRemaining = _timerSeconds;
      _selectedIndex = null;
      _selectedCorrect = null;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      final int next = _secondsRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        _finish(passed: false, failReason: FailReason.timerExpired);
        return;
      }
      setState(() => _secondsRemaining = next);
    });

    SemanticsService.announce(
      AppLocalizations.of(context).gameplayProgress(_index + 1, _questions.length),
      Directionality.of(context),
    );
  }

  Future<void> _answer(int optionIndex) async {
    if (_selectedIndex != null || _finished) return;
    _ticker?.cancel();

    final _PracticeQuestion question = _questions[_index];
    final bool correct = optionIndex == question.correctIndex;
    final AppLocalizations l10n = AppLocalizations.of(context);

    setState(() {
      _selectedIndex = optionIndex;
      _selectedCorrect = correct;
      if (correct) _correctCount += 1;
    });
    SemanticsService.announce(
      correct ? l10n.gameplayCorrect : l10n.gameplayWrong,
      Directionality.of(context),
    );

    await Future<void>.delayed(_feedbackPause);
    if (!mounted) return;

    // Same rule as ranked mode: one wrong answer ends the attempt (design-spec
    // §1D), so practice teaches the same pressure.
    if (!correct) {
      _finish(passed: false, failReason: FailReason.wrongAnswer);
      return;
    }

    if (_index + 1 >= _questions.length) {
      _finish(passed: true, failReason: null);
      return;
    }

    setState(() => _index += 1);
    _beginQuestion();
  }

  Future<void> _finish({required bool passed, required FailReason? failReason}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    _attemptClock.stop();

    final AnalyticsService analytics = context.read<AnalyticsService>();
    if (passed) {
      analytics.track('practice_level_completed', properties: <String, Object?>{
        'level_id': widget.args.levelNumber,
        'attempts_taken': widget.args.attemptNumber,
        'completion_time_ms': _attemptClock.elapsedMilliseconds,
      });
    } else {
      analytics.track('practice_level_failed', properties: <String, Object?>{
        'level_id': widget.args.levelNumber,
        'fail_reason': failReason == FailReason.timerExpired
            ? 'timer_expired'
            : 'wrong_answer',
        'question_index_at_fail': _index,
      });
    }

    // Whether the same level is unlocked in ranked mode decides which CTA M-20
    // offers. Practice itself never unlocks anything, so this is a read.
    bool unlockedInMainMode = false;
    try {
      final List<int> completions = await context.read<GameRepository>().completions();
      final int highest = completions.isEmpty
          ? 0
          : completions.reduce((int a, int b) => a > b ? a : b);
      unlockedInMainMode = widget.args.levelNumber <= highest + 1;
    } on Object {
      // Offline practice is the normal case; leaving this false simply shows the
      // "Practice again" CTA instead of the ranked one.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      Routes.practiceResult,
      arguments: PracticeResultArgs(
        levelNumber: widget.args.levelNumber,
        passed: passed,
        correctCount: _correctCount,
        totalCount: _questions.length,
        attemptNumber: widget.args.attemptNumber,
        failReason: failReason,
        questionIndexAtFail: _index,
        elapsedMs: _attemptClock.elapsedMilliseconds,
        levelUnlockedInMainMode: unlockedInMainMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    if (_questions.isEmpty) {
      final ContentService content = context.read<ContentService>();
      final String message = content.isOfflinePracticeLevel(widget.args.levelNumber)
          ? l10n.practiceLevelNotReady
          : l10n.practiceLevelOfflineOnly;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.levelDetailTitle(widget.args.levelNumber))),
        body: EmptyView(
          message: message,
          icon: Icons.hourglass_empty_rounded,
          actionLabel: l10n.actionClose,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final _PracticeQuestion question = _questions[_index];
    final SessionUser? user = context.watch<SessionController>().user;
    final bool readAloud =
        user?.ageGroup == AgeGroup.kid || user?.ageGroup == AgeGroup.youth;

    return Scaffold(
      appBar: AppBar(
        title: QuestionProgressLabel(index: _index + 1, total: _questions.length),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: TimerDisplay(
              secondsRemaining: _secondsRemaining,
              totalSeconds: _timerSeconds,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: Layout.useWideLayout(context) ? 900 : Layout.contentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.school_outlined, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.gameplayPracticeBadge,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AdaptiveTwoPane(
                  primary: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      QuestionPrompt(
                        variantType: question.source.variantType,
                        questionText: question.source.questionText,
                        verseReference: question.source.verseReference,
                        verseExcerpt: question.source.verseExcerpt,
                        imageAssetKey: question.source.imageAssetKey,
                        imageAltText: question.source.imageAltText,
                      ),
                      if (readAloud) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        ReadAloudButton(
                          text: question.source.questionText,
                          verseReference: question.source.verseReference,
                          verseExcerpt: question.source.verseExcerpt,
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
                          state: _selectedIndex != i || _selectedCorrect == null
                              ? AnswerOptionState.idle
                              : _selectedCorrect!
                                  ? AnswerOptionState.correct
                                  : AnswerOptionState.wrong,
                          onPressed:
                              _selectedIndex != null ? null : () => _answer(i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeQuestion {
  const _PracticeQuestion({
    required this.source,
    required this.options,
    required this.correctIndex,
  });

  final PackQuestion source;
  final List<String> options;
  final int correctIndex;
}
