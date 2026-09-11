import 'package:flutter/material.dart';

import '../features/map/parchment_codex_tokens.dart';

/// Parchment Codex wordmark — replaces the Material icon placeholder on splash.
class AnointedWordmark extends StatelessWidget {
  const AnointedWordmark({
    super.key,
    this.compact = false,
    this.showTagline = true,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20 : 28,
            vertical: compact ? 16 : 22,
          ),
          decoration: BoxDecoration(
            color: ParchmentColors.cream,
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            border: Border.all(color: ParchmentColors.gold.withOpacity(0.45), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ParchmentColors.ink.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'ANOINTED',
                style: ParchmentText.karla(
                  size: compact ? 22 : 28,
                  weight: FontWeight.w800,
                  color: ParchmentColors.gold,
                  letterSpacing: compact ? 4 : 6,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: compact ? 48 : 64,
                height: 2,
                color: ParchmentColors.goldLight,
              ),
              Text(
                'Bible Character Quiz',
                style: ParchmentText.cormorant(
                  size: compact ? 16 : 18,
                  weight: FontWeight.w500,
                  color: ParchmentColors.brown,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Know the heroes. Learn the story.',
            style: ParchmentText.karla(
              size: 13,
              color: ParchmentColors.inkMuted(0.65),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
