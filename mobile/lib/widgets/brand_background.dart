import 'package:flutter/material.dart';

import '../features/map/parchment_codex_tokens.dart';

/// The aged-paper wash sitting behind every screen.
///
/// This is what shows through on any screen with a transparent `Scaffold` — the
/// theme sets `scaffoldBackgroundColor: Colors.transparent` app-wide, so it is
/// the actual background of Settings, Welcome, sign-in, consent, onboarding and
/// the purchase flow. The branded screens (level map, profile, leaderboard,
/// practice, support) each cover it with an opaque `ParchmentColors.page`, which
/// is why an earlier coral/orchid/sky-blue gradient here went unnoticed on those
/// and made the uncovered screens look like a different app.
///
/// Kept deliberately low-contrast: it is a backdrop for cream cards and ink
/// text, not a feature. The warm spots are mottling, not orbs.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: <double>[0.0, 0.55, 1.0],
                colors: <Color>[
                  ParchmentColors.cream,
                  ParchmentColors.page,
                  ParchmentColors.strip,
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _Wash(color: ParchmentColors.goldPale, size: 300),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: _Wash(color: ParchmentColors.creamDark, size: 260),
          ),
          Positioned(
            bottom: 90,
            right: -50,
            child: _Wash(color: ParchmentColors.goldPale, size: 220),
          ),
          Positioned(
            bottom: -70,
            left: 10,
            child: _Wash(color: ParchmentColors.strip, size: 240),
          ),
        ],
      ),
    );
  }
}

/// A soft radial stain, fading to nothing at its edge so it never draws a rim.
class _Wash extends StatelessWidget {
  const _Wash({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withOpacity(0.55),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
