import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/map/parchment_codex_tokens.dart';

/// Offline fallback portrait — deterministic parchment-style illustration.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    super.key,
    required this.label,
    this.assetKey,
  });

  final String label;
  final String? assetKey;

  int get _seed {
    final String source = assetKey ?? label;
    return source.codeUnits.fold<int>(0, (int a, int b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    final math.Random rng = math.Random(_seed);
    final String initial =
        label.trim().isEmpty ? '?' : label.trim().substring(0, 1).toUpperCase();
    final Color robe = Color.lerp(
      ParchmentColors.brown,
      ParchmentColors.current,
      rng.nextDouble(),
    )!;

    return CustomPaint(
      painter: _PortraitPainter(initial: initial, robeColor: robe, seed: _seed),
      child: const SizedBox.expand(),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({
    required this.initial,
    required this.robeColor,
    required this.seed,
  });

  final String initial;
  final Color robeColor;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rng = math.Random(seed);
    final Paint bg = Paint()..color = ParchmentColors.cream;
    canvas.drawRect(Offset.zero & size, bg);

    final Offset center = Offset(size.width / 2, size.height * 0.42);
    final double headR = size.width * 0.14;

    final Paint skin = Paint()..color = const Color(0xFFE8C9A0);
    canvas.drawCircle(center, headR, skin);

    final Paint hair = Paint()..color = ParchmentColors.ink.withOpacity(0.85);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: headR * 1.05),
      math.pi,
      math.pi,
      true,
      hair,
    );

    final Path robe = Path()
      ..moveTo(center.dx - headR * 1.8, size.height)
      ..quadraticBezierTo(
        center.dx,
        center.dy + headR * 1.2,
        center.dx + headR * 1.8,
        size.height,
      )
      ..close();
    canvas.drawPath(robe, Paint()..color = robeColor);

    final TextPainter text = TextPainter(
      text: TextSpan(
        text: initial,
        style: ParchmentText.cormorant(
          size: headR * 1.1,
          weight: FontWeight.w700,
          color: ParchmentColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(center.dx - text.width / 2, center.dy - text.height / 2),
    );

    for (int i = 0; i < 6; i++) {
      final double x = rng.nextDouble() * size.width;
      final double y = rng.nextDouble() * size.height * 0.25;
      canvas.drawCircle(
        Offset(x, y),
        2 + rng.nextDouble() * 2,
        Paint()..color = ParchmentColors.gold.withOpacity(0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) =>
      oldDelegate.initial != initial || oldDelegate.seed != seed;
}
