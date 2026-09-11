import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Cards are laid out three across, and the whole board must fit the screen
/// without scrolling — six pairs is twelve cards, an exact 3 x 4 grid.
const int kArkPairsPerGame = 6;
const int kArkGridColumns = 3;

/// Whether a card shows the male or the female of its pair.
enum _Mate { male, female }

class _AnimalCard {
  _AnimalCard({required this.pair, required this.mate});

  final ArkAnimalPair pair;
  final _Mate mate;

  bool faceUp = false;
  bool matched = false;
}

/// Level 2 — flip cards to reunite each animal with its mate, two by two.
class AnimalMatchingGame extends StatefulWidget {
  const AnimalMatchingGame({
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
  State<AnimalMatchingGame> createState() => _AnimalMatchingGameState();
}

class _AnimalMatchingGameState extends State<AnimalMatchingGame> {
  /// Four, not five. With six pairs on a twelve-card board, five hearts let a
  /// child fail four times and still finish — close enough to a third of all
  /// guesses that random tapping tended to win.
  static const int _startingLives = 4;
  static const Duration _mismatchPause = Duration(milliseconds: 800);

  /// How long every unmatched card is shown when the mercy reveal fires.
  static const Duration _mercyReveal = Duration(seconds: 1);

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  final math.Random _random = math.Random();

  late List<_AnimalCard> _board;
  int? _firstIndex;
  int _lives = _startingLives;
  bool _busy = false;

  /// Unlimited hearts, for a child who wants to explore rather than compete.
  bool _practice = false;

  /// The one-time helping hand at the last heart.
  bool _mercyUsed = false;
  bool _revealing = false;

  int get _pairsFound =>
      _board.where((_AnimalCard c) => c.matched).length ~/ 2;

  int get _totalPairs =>
      _board.map((_AnimalCard c) => c.pair.id).toSet().length;

  bool get _won => _pairsFound == _totalPairs;

  bool get _lost => !_practice && _lives <= 0 && !_won;

  @override
  void initState() {
    super.initState();
    _board = _deal();
    _audio.startCreationAmbience(track: KidsZoneBgm.funky);
  }

  @override
  void dispose() {
    _audio.stopAmbience();
    super.dispose();
  }

  List<_AnimalCard> _deal() {
    // Draw this game's animals from the wider catalogue, so replaying brings a
    // different set aboard while the board still fits one screen.
    final List<ArkAnimalPair> pool =
        List<ArkAnimalPair>.of(widget.definition.arkAnimals)..shuffle(_random);
    final List<ArkAnimalPair> chosen =
        pool.take(math.min(kArkPairsPerGame, pool.length)).toList();

    final List<_AnimalCard> cards = <_AnimalCard>[
      for (final ArkAnimalPair pair in chosen) ...<_AnimalCard>[
        _AnimalCard(pair: pair, mate: _Mate.male),
        _AnimalCard(pair: pair, mate: _Mate.female),
      ],
    ];
    cards.shuffle(_random);
    return cards;
  }

  Future<void> _tap(int index) async {
    if (_busy || _won || _lost) return;
    final _AnimalCard tapped = _board[index];
    if (tapped.matched || tapped.faceUp) return;

    setState(() => tapped.faceUp = true);
    _audio.playSparkle();

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final int firstIndex = _firstIndex!;
    _firstIndex = null;
    final _AnimalCard first = _board[firstIndex];

    // Each species has exactly one male and one female, so a species match is
    // always a male/female pair.
    if (first.pair.id == tapped.pair.id) {
      _audio.playCorrect();
      setState(() {
        first.matched = true;
        tapped.matched = true;
      });
      if (!mounted) return;
      SemanticsService.announce(
        AppLocalizations.of(context).kidsZoneArkPairFound(tapped.pair.label),
        Directionality.of(context),
      );
      if (_won) {
        _audio.playCelebrate();
        setState(() {});
      }
      return;
    }

    setState(() {
      _busy = true;
      if (!_practice) _lives = math.max(0, _lives - 1);
    });
    _audio.playConnect();

    await Future<void>.delayed(_mismatchPause);
    if (!mounted) return;
    setState(() {
      first.faceUp = false;
      tapped.faceUp = false;
      _busy = false;
    });

    // Down to the last heart with pairs still hidden is where a child stops
    // thinking and starts tapping at random. One look at the board teaches the
    // positions without handing over the answer.
    if (!_practice && _lives == 1 && !_mercyUsed && !_won) {
      await _showMercyReveal();
    }
  }

  Future<void> _showMercyReveal() async {
    _mercyUsed = true;
    if (!mounted) return;

    SemanticsService.announce(
      AppLocalizations.of(context).kidsZoneArkMercyReveal,
      Directionality.of(context),
    );
    setState(() {
      _revealing = true;
      _busy = true;
    });

    await Future<void>.delayed(_mercyReveal);
    if (!mounted) return;
    setState(() {
      _revealing = false;
      _busy = false;
    });
  }

  void _restart() {
    setState(() {
      _board = _deal();
      _firstIndex = null;
      _lives = _startingLives;
      _busy = false;
      _mercyUsed = false;
      _revealing = false;
    });
  }

  void _togglePractice() {
    setState(() {
      _practice = !_practice;
      if (_practice) _lives = _startingLives;
    });
  }

  void _finish() {
    // Practice runs still complete the stop — a child who wants to explore
    // should not be locked out of the rest of the adventure — but the stars
    // stay honest, because unlimited hearts is not the same achievement.
    final int stars = _practice
        ? 1
        : switch (_lives) {
            4 => 3,
            3 || 2 => 2,
            _ => 1,
          };
    widget.onComplete(stars);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneArkMatchHint,
      readAloudText: l10n.kidsZoneArkMatchHint,
      pauseKidsZoneBgm: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.kidsZoneArkPairsFound(_pairsFound, _totalPairs),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        KidsZoneText.nunito(size: 14, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Spacer(),
                Semantics(
                  button: true,
                  toggled: _practice,
                  label: l10n.kidsZoneArkPracticeMode,
                  child: IconButton(
                    onPressed: _togglePractice,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.kidsZoneArkPracticeMode,
                    icon: Icon(
                      _practice
                          ? Icons.school_rounded
                          : Icons.school_outlined,
                      size: 20,
                      color: _practice
                          ? ArkColors.leaf
                          : KidsZoneColors.inkMuted,
                    ),
                  ),
                ),
                if (_practice)
                  Semantics(
                    label: l10n.kidsZoneArkHeartsUnlimited,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.favorite_rounded,
                            size: 20, color: ArkColors.heart),
                        Icon(Icons.all_inclusive_rounded,
                            size: 18, color: ArkColors.heart),
                      ],
                    ),
                  )
                else
                  Semantics(
                    label: l10n.kidsZoneArkLivesLeft(_lives),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(_startingLives, (int i) {
                        return Icon(
                          i < _lives
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: ArkColors.heart,
                        );
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Stack(
                children: <Widget>[
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      // Derive the card shape from the space actually
                      // available, so the whole board fits every screen
                      // without scrolling or overflowing.
                      const double gap = AppSpacing.md;
                      final int rows =
                          (_board.length / kArkGridColumns).ceil();
                      final double cardWidth = (constraints.maxWidth -
                              gap * (kArkGridColumns - 1)) /
                          kArkGridColumns;
                      final double cardHeight =
                          (constraints.maxHeight - gap * (rows - 1)) / rows;

                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kArkGridColumns,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: cardWidth / cardHeight,
                        ),
                        itemCount: _board.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _CardTile(
                            card: _board[index],
                            height: cardHeight,
                            forceReveal: _revealing,
                            onTap: () => _tap(index),
                          );
                        },
                      );
                    },
                  ),
                  if (_won || _lost)
                    _ResultOverlay(
                      won: _won,
                      title: _won
                          ? l10n.kidsZoneArkMatchWonTitle
                          : l10n.kidsZoneArkMatchLostTitle,
                      body: _won
                          ? l10n.kidsZoneArkMatchWonBody
                          : l10n.kidsZoneArkMatchLostBody,
                      actionLabel: _won
                          ? l10n.kidsZoneGameFinish
                          : l10n.kidsZoneArkTryAgain,
                      onAction: _won ? _finish : _restart,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.height,
    required this.onTap,
    this.forceReveal = false,
  });

  final _AnimalCard card;

  /// Laid-out card height, so the picture and labels scale with the board.
  final double height;
  final VoidCallback onTap;

  /// The one-second mercy look at the whole board.
  final bool forceReveal;

  @override
  Widget build(BuildContext context) {
    final bool revealed = card.faceUp || card.matched || forceReveal;

    return Semantics(
      button: true,
      label: revealed ? card.pair.label : null,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: revealed ? 1 : 0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double t, _) {
            final bool showFront = t >= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(t * math.pi),
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _CardFront(card: card, height: height),
                    )
                  : _CardBack(height: height),
            );
          },
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[ArkColors.timber, ArkColors.timberDark],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ArkColors.timberDark.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.directions_boat_rounded,
          color: ArkColors.straw,
          size: (height * 0.34).clamp(20.0, 46.0),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card, required this.height});

  final _AnimalCard card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isMale = card.mate == _Mate.male;
    final double emojiSize = (height * 0.40).clamp(22.0, 56.0);
    final double labelSize = (height * 0.13).clamp(9.0, 15.0);
    final double badgeSize = (height * 0.20).clamp(14.0, 26.0);

    return Container(
      decoration: BoxDecoration(
        color: card.matched
            ? card.pair.color.withOpacity(0.35)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: card.matched ? ArkColors.leaf : card.pair.color,
          width: card.matched ? 3 : 2,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Plain TextStyle, not Nunito — the platform emoji font must win so
          // the animal renders as a full-colour picture.
          Text(
            card.pair.emoji,
            style: TextStyle(fontSize: emojiSize),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              card.pair.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsZoneText.nunito(
                size: labelSize,
                weight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            isMale ? Icons.male_rounded : Icons.female_rounded,
            size: badgeSize,
            color: isMale ? const Color(0xFF42A5F5) : const Color(0xFFEC407A),
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.won,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final bool won;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            won ? Icons.celebration_rounded : Icons.favorite_border_rounded,
            size: 60,
            color: won ? ArkColors.straw : ArkColors.heart,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 22,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 15,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(won ? Icons.check_rounded : Icons.refresh_rounded),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: won ? ArkColors.leaf : ArkColors.timber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
