import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../../../widgets/gameplay_widgets.dart';
import '../../../widgets/read_aloud_button.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';
import '../widgets/creation_world_view.dart';

/// Level 1 — answer God's questions after the intro narration (listening comprehension).
class ListenAndAnswerGame extends StatefulWidget {
  const ListenAndAnswerGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  @override
  State<ListenAndAnswerGame> createState() => _ListenAndAnswerGameState();
}

class _ListenAndAnswerGameState extends State<ListenAndAnswerGame> {
  static const Duration _feedbackPause = Duration(milliseconds: 900);

  /// The question is always heard before the choices appear; this is the floor
  /// on that beat, so the level still reads as listening-first on a device with
  /// no working speech engine.
  static const Duration _minListenBeat = Duration(milliseconds: 600);

  /// Never strand a child waiting on speech that will not arrive.
  static const Duration _maxListenWait = Duration(seconds: 12);

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;

  late final List<_ShuffledQuestion> _questions;
  int _questionIndex = 0;
  int _retryCount = 0;
  int? _selectedIndex;
  bool? _selectedCorrect;
  CreationCelebration? _celebrating;

  /// While true the prompt is being read and the answers stay hidden.
  bool _listening = true;

  late final TextToSpeechService _tts;

  @override
  void initState() {
    super.initState();
    // Captured here: looking the service up in dispose() is invalid once the
    // element is unmounting, which left narration playing on after leaving.
    _tts = context.read<TextToSpeechService>();
    _questions = _buildQuestions(widget.definition.listeningQuestions);
    _audio.startCreationAmbience(track: KidsZoneBgm.interesting);
    WidgetsBinding.instance.addPostFrameCallback((_) => _readQuestion());
  }

  @override
  void dispose() {
    _audio.stopAmbience();
    _tts.stop();
    super.dispose();
  }

  /// Builds each question's answer set, narrowing the number of choices as the
  /// level progresses (see [kGenesisLevel1OptionRamp]). The distractors kept are
  /// the ones listed first — the closest near-misses — so the final two-option
  /// questions are a real discrimination rather than a coin toss.
  List<_ShuffledQuestion> _buildQuestions(List<ListeningQuestion> source) {
    final Random random = Random();

    return <_ShuffledQuestion>[
      for (int i = 0; i < source.length; i++) _shape(source[i], i, random),
    ];
  }

  _ShuffledQuestion _shape(ListeningQuestion q, int index, Random random) {
    final int wanted = kGenesisLevel1OptionRamp[
        min(index, kGenesisLevel1OptionRamp.length - 1)];
    final int optionCount = wanted.clamp(2, q.allOptions.length);

    final List<String> options = <String>[
      q.correctAnswer,
      ...q.distractors.take(optionCount - 1),
    ]..shuffle(random);

    return _ShuffledQuestion(
      source: q,
      options: options,
      correctIndex: options.indexOf(q.correctAnswer),
    );
  }

  /// Speaks the prompt, then reveals the answers.
  Future<void> _readQuestion() async {
    if (!mounted) return;
    setState(() => _listening = true);

    final TextToSpeechService tts = _tts;
    final String prompt = _questions[_questionIndex].source.prompt;

    // Deliberately not awaited: on a device whose speech engine is missing or
    // wedged, `speak` can hang indefinitely, and awaiting it would strand the
    // child on "Listen to the question…" with no way to answer. Instead we hold
    // for a short beat, then wait only as long as speech is actually running.
    unawaited(tts.speak(prompt).catchError((Object _) {}));

    await Future<void>.delayed(_minListenBeat);
    if (!mounted) return;
    await _awaitSpeechEnd(tts);
    if (!mounted) return;

    setState(() => _listening = false);
    SemanticsService.announce(
      AppLocalizations.of(context).kidsZoneListenChooseAnswer,
      Directionality.of(context),
    );
  }

  /// `speak` returns once speech *starts*; completion arrives on the service's
  /// notifier, so wait on that rather than on the future.
  Future<void> _awaitSpeechEnd(TextToSpeechService tts) async {
    if (!tts.isSpeaking) return;

    final Completer<void> done = Completer<void>();
    void listener() {
      if (!tts.isSpeaking && !done.isCompleted) done.complete();
    }

    tts.addListener(listener);
    try {
      await done.future.timeout(_maxListenWait, onTimeout: () {});
    } finally {
      tts.removeListener(listener);
    }
  }

  Future<void> _answer(int optionIndex) async {
    if (_listening || _selectedIndex != null || _celebrating != null) return;

    final _ShuffledQuestion question = _questions[_questionIndex];
    final bool correct = optionIndex == question.correctIndex;
    final AppLocalizations l10n = AppLocalizations.of(context);

    setState(() {
      _selectedIndex = optionIndex;
      _selectedCorrect = correct;
      if (!correct) _retryCount += 1;
      if (correct) _celebrating = question.source.celebration;
    });

    SemanticsService.announce(
      correct ? l10n.gameplayCorrect : l10n.kidsZoneListenWrong,
      Directionality.of(context),
    );

    if (correct) await _audio.playCorrect();

    await Future<void>.delayed(_feedbackPause);
    if (!mounted) return;

    if (!correct) {
      setState(() {
        _selectedIndex = null;
        _selectedCorrect = null;
      });
      return;
    }

    setState(() => _celebrating = null);

    if (_questionIndex + 1 >= _questions.length) {
      await _audio.playCelebrate();
      final int stars = _retryCount == 0 ? 3 : (_retryCount <= 3 ? 2 : 1);
      widget.onComplete(stars);
      return;
    }

    setState(() {
      _questionIndex += 1;
      _selectedIndex = null;
      _selectedCorrect = null;
    });
    await _readQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final _ShuffledQuestion question = _questions[_questionIndex];

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneLevel1Intro,
      readAloudText: question.source.prompt,
      pauseKidsZoneBgm: true,
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Four options plus the scene art can exceed a short screen, so the
          // question scrolls rather than clipping the last answer.
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CreationWorldView(day: 7),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                QuestionProgressLabel(index: _questionIndex + 1, total: _questions.length),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: KidsZoneColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    question.source.prompt,
                    style: KidsZoneText.nunito(size: 18, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReadAloudButton(text: question.source.prompt, pauseKidsZoneBgm: true),
                const SizedBox(height: AppSpacing.lg),
                // Listening first: the answers stay hidden until the question
                // has been read, so a child still learning to read is never
                // racing the text.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _listening
                      ? _ListeningBanner(
                          key: const ValueKey<String>('listening'),
                          label: l10n.kidsZoneListenNowListen,
                        )
                      : Column(
                          key: ValueKey<int>(_questionIndex),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (int i = 0; i < question.options.length; i++)
                              AnswerOptionButton(
                                label: question.options[i],
                                state: _selectedIndex != i ||
                                        _selectedCorrect == null
                                    ? AnswerOptionState.idle
                                    : _selectedCorrect!
                                        ? AnswerOptionState.correct
                                        : AnswerOptionState.wrong,
                                onPressed: _selectedIndex != null
                                    ? null
                                    : () => _answer(i),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (_celebrating != null) CreationCelebrationBurst(type: _celebrating!),
        ],
      ),
    );
  }
}

/// Shown in place of the answers while the question is being read aloud.
class _ListeningBanner extends StatelessWidget {
  const _ListeningBanner({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: KidsZoneColors.grass.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.hearing_rounded,
              size: 40,
              color: KidsZoneColors.grass,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(size: 16, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuffledQuestion {
  const _ShuffledQuestion({
    required this.source,
    required this.options,
    required this.correctIndex,
  });

  final ListeningQuestion source;
  final List<String> options;
  final int correctIndex;
}
