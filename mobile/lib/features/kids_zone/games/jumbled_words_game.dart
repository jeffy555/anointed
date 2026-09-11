import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';
import '../widgets/creation_world_view.dart';

/// Level 3 — unscramble words into correct creation sentences.
class JumbledWordsGame extends StatefulWidget {
  const JumbledWordsGame({
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
  State<JumbledWordsGame> createState() => _JumbledWordsGameState();
}

class _JumbledWordsGameState extends State<JumbledWordsGame>
    with SingleTickerProviderStateMixin {
  /// Wrong taps in a row on one sentence before the next word is pointed out.
  ///
  /// Reading fluency varies enormously at 5–7, and a child who cannot yet read
  /// a word should not be stranded on it. Three misses is enough to show they
  /// are guessing rather than thinking.
  static const int _hintAfterWrongTaps = 3;

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;

  late final AnimationController _hintPulse;

  int _sentenceIndex = 0;
  late List<String> _bank;
  final List<String> _built = <String>[];
  int _wrongTapStreak = 0;
  int _totalWrongTaps = 0;
  String? _rejectedWord;
  bool _showRainbow = false;

  JumbledSentence get _sentence => widget.definition.jumbledSentences[_sentenceIndex];

  /// The word the sentence needs next, or null once it is complete.
  String? get _nextWord => _built.length < _sentence.words.length
      ? _sentence.words[_built.length]
      : null;

  bool get _hintActive => _wrongTapStreak >= _hintAfterWrongTaps;

  /// Index in the bank of the word to pulse — the first copy, so repeated words
  /// like "on" still point somewhere definite.
  int get _hintedBankIndex {
    if (!_hintActive) return -1;
    final String? next = _nextWord;
    if (next == null) return -1;
    return _bank.indexOf(next);
  }

  @override
  void initState() {
    super.initState();
    _audio.startCreationAmbience(track: KidsZoneBgm.thrilling);
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shuffleBank();
  }

  @override
  void dispose() {
    _hintPulse.dispose();
    super.dispose();
  }

  void _shuffleBank() {
    _bank = List<String>.of(_sentence.words)..shuffle(Random());
    _built.clear();
    _wrongTapStreak = 0;
    _rejectedWord = null;
  }

  Future<void> _pickWord(String word) async {
    final String? expected = _nextWord;
    if (expected == null) return;

    // Words go down in order. A wrong pick is refused gently rather than left
    // to fail at the end of the sentence, which is where frustration built up.
    if (word != expected) {
      _audio.playConnect();
      setState(() {
        _wrongTapStreak += 1;
        _totalWrongTaps += 1;
        _rejectedWord = word;
      });

      if (_hintActive && mounted) {
        SemanticsService.announce(
          AppLocalizations.of(context).kidsZoneJumbleHint(expected),
          Directionality.of(context),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _rejectedWord = null);
      return;
    }

    _audio.playSparkle();
    setState(() {
      _bank.remove(word);
      _built.add(word);
      _wrongTapStreak = 0;
      _rejectedWord = null;
    });
  }

  /// Tapping a placed word takes it back, along with anything after it, so the
  /// sentence stays a valid prefix.
  void _undoFrom(int index) {
    setState(() {
      final List<String> removed = _built.sublist(index);
      _built.removeRange(index, _built.length);
      _bank.addAll(removed);
      _wrongTapStreak = 0;
      _rejectedWord = null;
    });
  }

  void _check(AppLocalizations l10n) {
    final String attempt = _built.join(' ');
    final String expected = _sentence.words.join(' ');
    if (attempt != expected) {
      setState(() => _totalWrongTaps += 1);
      return;
    }

    _audio.playCorrect();

    if (_sentenceIndex + 1 >= widget.definition.jumbledSentences.length) {
      setState(() => _showRainbow = true);
      _audio.playCelebrate();
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        // Placement is ordered now, so a finished sentence is always correct;
        // stars come from how much guessing it took to get there.
        final int stars = _totalWrongTaps <= 2
            ? 3
            : (_totalWrongTaps <= 6 ? 2 : 1);
        widget.onComplete(stars);
      });
      return;
    }

    setState(() {
      _sentenceIndex += 1;
      _shuffleBank();
    });
  }

  void _resetSentence() {
    setState(_shuffleBank);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (_showRainbow) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const CreationWorldView(day: 7, showRainbow: true),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.celebration_rounded, size: 80, color: KidsZoneColors.star),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.kidsZoneJumbleComplete,
                    textAlign: TextAlign.center,
                    style: KidsZoneText.nunito(size: 24, weight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      body: KidsZoneBoardLayout(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gap: AppSpacing.lg,
        // Roomier than the default: the sentence being built lives in the
        // header here, and it is half the game rather than a caption above it.
        headerMaxFraction: 0.55,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.kidsZoneJumbleProgress(_sentenceIndex + 1, widget.definition.jumbledSentences.length),
              style: KidsZoneText.nunito(size: 14, weight: FontWeight.w700, color: KidsZoneColors.inkMuted),
            ),
            Text(
              _sentence.hint,
              style: KidsZoneText.nunito(size: 13, weight: FontWeight.w600, color: KidsZoneColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: KidsZoneColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KidsZoneColors.grass.withOpacity(0.4)),
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _built.isEmpty
                    ? <Widget>[
                        Text(
                          l10n.kidsZoneJumbleTapWords,
                          style: KidsZoneText.nunito(size: 14, color: KidsZoneColors.inkMuted),
                        ),
                      ]
                    : <Widget>[
                        for (int i = 0; i < _built.length; i++)
                          ActionChip(
                            label: Text(_built[i]),
                            onPressed: () => _undoFrom(i),
                          ),
                      ],
              ),
            ),
            ),
            if (_hintActive && _nextWord != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_rounded,
                    size: 18,
                    color: KidsZoneColors.star,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.kidsZoneJumbleHint(_nextWord!),
                      style: KidsZoneText.nunito(
                        size: 13,
                        weight: FontWeight.w700,
                        color: KidsZoneColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        board: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (int i = 0; i < _bank.length; i++)
                _BankWord(
                  word: _bank[i],
                  hinted: i == _hintedBankIndex,
                  rejected: _bank[i] == _rejectedWord,
                  pulse: _hintPulse,
                  onTap: () => _pickWord(_bank[i]),
                ),
            ],
          ),
        ),
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          kidsZonePrimaryButton(
            label: l10n.kidsZoneJumbleCheck,
            onPressed: _built.length == _sentence.words.length ? () => _check(l10n) : null,
          ),
          TextButton(onPressed: _resetSentence, child: Text(l10n.kidsZoneJumbleReset)),
        ],
      ),
    );
  }
}

/// A word in the bank. Pulses gently when it is the one the child needs next
/// and they have already guessed wrong three times; flashes briefly when tapped
/// out of order.
class _BankWord extends StatelessWidget {
  const _BankWord({
    required this.word,
    required this.hinted,
    required this.rejected,
    required this.pulse,
    required this.onTap,
  });

  final String word;
  final bool hinted;
  final bool rejected;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, _) {
        final double t = hinted ? pulse.value : 0;

        return Transform.scale(
          scale: 1 + t * 0.06,
          child: Material(
            color: rejected
                ? const Color(0xFFFFCDD2)
                : hinted
                    ? Color.lerp(
                        KidsZoneColors.star.withOpacity(0.20),
                        KidsZoneColors.star.withOpacity(0.45),
                        t,
                      )!
                    : KidsZoneColors.grass.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: hinted
                    ? KidsZoneColors.star
                    : Colors.transparent,
                width: hinted ? 2 : 0,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  word,
                  style: KidsZoneText.nunito(size: 15, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
