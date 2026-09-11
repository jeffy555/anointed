import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

class _BoardCard {
  _BoardCard({required this.pairId, required this.card});

  final String pairId;
  final MatchPairCard card;
  bool faceUp = false;
  bool matched = false;
}

/// Memory match — flip cards to pair Bible characters and items.
class MatchPairsGame extends StatefulWidget {
  const MatchPairsGame({
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
  State<MatchPairsGame> createState() => _MatchPairsGameState();
}

class _MatchPairsGameState extends State<MatchPairsGame> {
  late final List<_BoardCard> _board;
  int? _firstIndex;
  int _moves = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final List<_BoardCard> cards = <_BoardCard>[];
    for (final MatchPairCard card in widget.definition.matchCards) {
      cards.add(_BoardCard(pairId: card.id, card: card));
      cards.add(_BoardCard(pairId: card.id, card: card));
    }
    cards.shuffle(Random());
    _board = cards;
  }

  int get _matchedCount => _board.where((_BoardCard c) => c.matched).length ~/ 2;

  void _tap(int index) {
    if (_busy) return;
    final _BoardCard tapped = _board[index];
    if (tapped.matched || tapped.faceUp) return;

    setState(() => tapped.faceUp = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final int first = _firstIndex!;
    _firstIndex = null;
    _moves += 1;
    final _BoardCard firstCard = _board[first];

    if (firstCard.pairId == tapped.pairId) {
      setState(() {
        firstCard.matched = true;
        tapped.matched = true;
      });
      if (_matchedCount == widget.definition.matchCards.length) {
        final int stars = _moves <= 8 ? 3 : (_moves <= 12 ? 2 : 1);
        widget.onComplete(stars);
      }
      return;
    }

    _busy = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        firstCard.faceUp = false;
        tapped.faceUp = false;
        _busy = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Text(
              l10n.kidsZoneGameMatchProgress(_matchedCount, widget.definition.matchCards.length),
              style: KidsZoneText.nunito(size: 14, weight: FontWeight.w700, color: KidsZoneColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: _board.length,
                itemBuilder: (BuildContext context, int index) {
                  final _BoardCard entry = _board[index];
                  final bool showFace = entry.faceUp || entry.matched;
                  return Material(
                    color: showFace ? entry.card.color.withOpacity(0.18) : KidsZoneColors.card,
                    borderRadius: BorderRadius.circular(12),
                    elevation: showFace ? 2 : 1,
                    child: InkWell(
                      onTap: () => _tap(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: showFace
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(entry.card.icon, color: entry.card.color, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.card.label,
                                    style: KidsZoneText.nunito(size: 10, weight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : Icon(Icons.auto_awesome, color: KidsZoneColors.inkMuted.withOpacity(0.4)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
