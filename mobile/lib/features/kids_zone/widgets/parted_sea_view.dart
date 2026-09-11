import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/moses_exodus_level.dart';

/// The Red Sea, seen down the length of the dry path.
///
/// One `separation` value drives the whole picture: at 0 the sea is whole and
/// the path is gone, at 1 the walls stand at full height and the seabed is dry
/// all the way across. Phase 1 drives it up, phase 3 drives it back down — the
/// same geometry running in reverse, so the water returning is visibly the
/// undoing of the water parting rather than a different effect that happens to
/// look similar.
class PartedSeaView extends StatelessWidget {
  const PartedSeaView({
    super.key,
    required this.separation,
    required this.phase,
    required this.crossing,
    required this.arrived,
    this.chariotAdvance = -1,
    this.wheelWobble = 0,
    this.sink = 0,
    this.mosesRaised = 0,
    this.celebrating = false,
  });

  /// 0 = sea whole, 1 = walls at full height and the path dry.
  final double separation;

  /// Free-running seconds, for swell and idle motion.
  final double phase;

  /// How far the Israelites have walked, 0..1.
  final double crossing;

  /// How many of them are already safe on the far shore, 0..1.
  final double arrived;

  /// Chariot position along the path: 0 near shore, 1 far shore. Negative
  /// keeps them off the frame entirely.
  final double chariotAdvance;

  /// A decaying jolt after a wheel fouls, 0..1.
  final double wheelWobble;

  /// How far the chariots have gone under, 0..1.
  final double sink;

  /// How high Moses is holding the staff, 0..1.
  final double mosesRaised;

  final bool celebrating;

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PartedSeaPainter(
          separation: separation,
          phase: phase,
          crossing: crossing,
          arrived: arrived,
          chariotAdvance: chariotAdvance,
          wheelWobble: wheelWobble,
          sink: sink,
          mosesRaised: mosesRaised,
          celebrating: celebrating,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PartedSeaPainter extends CustomPainter {
  _PartedSeaPainter({
    required this.separation,
    required this.phase,
    required this.crossing,
    required this.arrived,
    required this.chariotAdvance,
    required this.wheelWobble,
    required this.sink,
    required this.mosesRaised,
    required this.celebrating,
  });

  final double separation;
  final double phase;
  final double crossing;
  final double arrived;
  final double chariotAdvance;
  final double wheelWobble;
  final double sink;
  final double mosesRaised;
  final bool celebrating;

  /// Half-width of the dry path at the near shore, as a fraction of width.
  static const double pathHalfWidth = 0.26;

  /// Where the far shore meets the sky.
  static const double horizonFraction = 0.34;

  // The Red Sea is red in name only — it is deep blue water. An earlier pass
  // took the name literally and the result looked like blood rather than sea.
  // Kept a colder, deeper blue than the Nile's teal so the two bodies of water
  // in this adventure still read as different places.
  static const Color _deep = Color(0xFF06263F);
  static const Color _mid = Color(0xFF0E5C86);
  static const Color _shallow = Color(0xFF2E9CC0);
  static const Color _crest = Color(0xFFD9F1F8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final double horizon = size.height * horizonFraction;

    _paintSky(canvas, size, horizon);
    _paintMountains(canvas, size, horizon);
    _paintFarShore(canvas, size, horizon);
    _paintSeabed(canvas, size, horizon);
    _paintWalls(canvas, size, horizon);
    // Before the chariots, not after. Painting the closed sea last covered
    // the sinking completely — the one moment the whole phase builds to was
    // being drawn over at exactly the frame it started.
    if (separation < 0.06) _paintStillSurface(canvas, size, horizon);
    if (chariotAdvance > -0.05) _paintChariots(canvas, size, horizon);
    _paintIsraelites(canvas, size, horizon);
    _paintMoses(canvas, size, horizon);
  }

  double _yFor(Size size, double horizon, double along) =>
      size.height - (size.height - horizon) * along.clamp(-0.4, 1.2);

  /// The path narrows toward the horizon.
  double _perspective(double along) => 1 - along.clamp(0.0, 1.0) * 0.66;

  // -------------------------------------------------------------------- sky

  void _paintSky(Canvas canvas, Size size, double horizon) {
    final Rect sky = Rect.fromLTWH(0, 0, size.width, horizon + 1);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: celebrating
              ? const <Color>[Color(0xFF2E6EA8), Color(0xFFF3C98A)]
              : const <Color>[
                  Color(0xFF0B1730),
                  Color(0xFF1E3A5F),
                  Color(0xFF6E7FA0)
                ],
        ).createShader(sky),
    );

    // Storm cloud driven back over the water — the pillar of cloud, and the
    // reason the light in this scene comes from one place.
    for (int i = 0; i < 5; i++) {
      final double x = size.width * (0.08 + i * 0.22) +
          math.sin(phase * 0.2 + i) * size.width * 0.02;
      final double y = horizon * (0.22 + (i % 3) * 0.12);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y),
            width: size.width * 0.42,
            height: horizon * 0.28),
        Paint()
          ..color = Colors.black.withOpacity(celebrating ? 0.10 : 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.05),
      );
    }

    // The pillar of fire over the path.
    final Rect pillar =
        Rect.fromLTWH(size.width * 0.41, 0, size.width * 0.18, horizon * 1.05);
    canvas.drawRect(
      pillar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            MosesColors.blessing.withOpacity(celebrating ? 0.30 : 0.42),
            MosesColors.blessing.withOpacity(0.0),
          ],
        ).createShader(pillar)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06),
    );
  }

  /// The range the sea is set against, and the outcrop Moses stands on.
  void _paintMountains(Canvas canvas, Size size, double horizon) {
    void ridge(double baseY, double height, Color color, double offset) {
      final Path p = Path()..moveTo(-size.width * 0.1, baseY);
      for (int i = 0; i <= 8; i++) {
        final double x = size.width * (i / 8) * 1.2 - size.width * 0.1;
        // A fixed silhouette, not noise — the same skyline every frame.
        final double peak =
            height * (0.45 + 0.55 * (math.sin(i * 1.7 + offset) * 0.5 + 0.5));
        p.lineTo(x, baseY - peak);
        p.lineTo(x + size.width * 0.075, baseY - peak * 0.55);
      }
      p.lineTo(size.width * 1.2, baseY);
      p.close();
      canvas.drawPath(p, Paint()..color = color);
    }

    ridge(horizon + 2, size.height * 0.20, const Color(0xFF16233B), 0.0);
    ridge(horizon + 4, size.height * 0.13, const Color(0xFF223452), 2.3);
  }

  void _paintFarShore(Canvas canvas, Size size, double horizon) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height * 0.035),
      Paint()..color = const Color(0xFF6E5540),
    );
  }

  // ------------------------------------------------------------------ water

  void _paintSeabed(Canvas canvas, Size size, double horizon) {
    if (separation <= 0.01) return;
    final Path bed = Path()
      ..moveTo(
          size.width * (0.5 - pathHalfWidth * _perspective(1) * separation),
          horizon)
      ..lineTo(
          size.width * (0.5 + pathHalfWidth * _perspective(1) * separation),
          horizon)
      ..lineTo(size.width * (0.5 + pathHalfWidth * separation), size.height)
      ..lineTo(size.width * (0.5 - pathHalfWidth * separation), size.height)
      ..close();
    canvas.drawPath(bed, Paint()..color = const Color(0xFF6B5637));
    for (int i = 1; i < 9; i++) {
      final double along = i / 9;
      final double y = _yFor(size, horizon, along);
      final double half =
          size.width * pathHalfWidth * separation * _perspective(along);
      canvas.drawLine(
        Offset(size.width * 0.5 - half * 0.75, y),
        Offset(size.width * 0.5 + half * 0.75, y),
        Paint()
          ..color = const Color(0xFF57452C).withOpacity(0.55)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintWalls(Canvas canvas, Size size, double horizon) {
    for (final double side in <double>[-1, 1]) {
      final Path wall = Path()
        ..moveTo(size.width * 0.5 + side * size.width, horizon);
      wall.lineTo(
          size.width *
              (0.5 + side * pathHalfWidth * _perspective(1) * separation),
          horizon);
      wall.lineTo(
          size.width * (0.5 + side * pathHalfWidth * separation), size.height);
      wall.lineTo(size.width * 0.5 + side * size.width, size.height);
      wall.close();

      canvas.drawPath(
        wall,
        Paint()
          ..shader = LinearGradient(
            begin: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: const <Color>[_deep, _mid, _shallow],
            stops: const <double>[0.0, 0.62, 1.0],
          ).createShader(Offset.zero & size),
      );

      // Swell running down the inner face, so the wall is held-back water
      // rather than a slab, and foam where it strains against itself.
      for (int i = 0; i < 14; i++) {
        final double along = i / 13;
        final double y = _yFor(size, horizon, along);
        final double inner = size.width *
            (0.5 + side * pathHalfWidth * separation * _perspective(along));
        final double swell =
            math.sin(phase * 2.2 + i * 0.7) * size.width * 0.016 * separation;
        canvas.drawCircle(
          Offset(inner + side * swell.abs(), y),
          math.max(1.5, size.width * 0.016 * _perspective(along)),
          Paint()..color = _crest.withOpacity(0.42 * separation),
        );
        if (i.isEven) {
          canvas.drawCircle(
            Offset(inner + side * swell.abs() * 1.6, y - size.height * 0.01),
            math.max(1, size.width * 0.009 * _perspective(along)),
            Paint()..color = Colors.white.withOpacity(0.28 * separation),
          );
        }
      }
    }
  }

  /// The sea once it is whole again: no path, no walls, just swell.
  void _paintStillSurface(Canvas canvas, Size size, double horizon) {
    final Rect sea =
        Rect.fromLTWH(0, horizon, size.width, size.height - horizon);
    canvas.drawRect(
      sea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_mid, _deep],
        ).createShader(sea),
    );
    for (int i = 0; i < 16; i++) {
      final double t = i / 15;
      final double y = horizon + (size.height - horizon) * t * t;
      final double drift =
          math.sin(phase * 1.1 + i * 0.9) * size.width * 0.03 * t;
      canvas.drawLine(
        Offset(-size.width * 0.1 + drift, y),
        Offset(size.width * 1.1 + drift, y),
        Paint()
          ..color = _crest.withOpacity(0.10 + 0.14 * t)
          ..strokeWidth = 1 + 2.5 * t,
      );
    }
  }

  // ----------------------------------------------------------------- people

  void _paintIsraelites(Canvas canvas, Size size, double horizon) {
    final int walking = ((1 - arrived) * 5).round();
    for (int i = 0; i < walking; i++) {
      final double along = (crossing - i * 0.09).clamp(0.0, 1.0);
      final double y = _yFor(size, horizon, along);
      final double scale = _perspective(along);
      _figure(
        canvas,
        Offset(size.width * (0.5 + (i.isEven ? -0.055 : 0.055)), y),
        size.height * 0.085 * scale,
        const Color(0xFFB98A5E),
      );
    }
    final int safe = (arrived * 6).round();
    for (int i = 0; i < safe; i++) {
      final double bounce =
          celebrating ? math.sin(phase * 5 + i).abs() * size.height * 0.012 : 0;
      _figure(
        canvas,
        Offset(size.width * (0.20 + i * 0.12),
            horizon + size.height * 0.030 - bounce),
        size.height * 0.045,
        const Color(0xFFD8C08F),
      );
    }
  }

  /// Moses, on the outcrop at the near shore, staff over the water.
  ///
  /// Standing in front of the range and facing the sea, so the child can see
  /// who is doing this — the parting and the returning both happen with him
  /// on screen, arm up.
  void _paintMoses(Canvas canvas, Size size, double horizon) {
    final double h = size.height * 0.20;
    final Offset feet = Offset(size.width * 0.135, size.height * 0.905);

    // The rock he stands on.
    final Path rock = Path()
      ..moveTo(feet.dx - h * 0.55, size.height)
      ..lineTo(feet.dx - h * 0.34, feet.dy + h * 0.02)
      ..lineTo(feet.dx + h * 0.30, feet.dy - h * 0.01)
      ..lineTo(feet.dx + h * 0.52, size.height)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF1B2C40));

    const Color robe = Color(0xFF6E4F7A);
    const Color skin = Color(0xFFE8C39A);

    // Robe.
    final Path gown = Path()
      ..moveTo(feet.dx - h * 0.16, feet.dy - h * 0.72)
      ..lineTo(feet.dx + h * 0.16, feet.dy - h * 0.72)
      ..lineTo(feet.dx + h * 0.24, feet.dy)
      ..lineTo(feet.dx - h * 0.24, feet.dy)
      ..close();
    canvas.drawPath(gown, Paint()..color = robe);
    canvas.drawRect(
      Rect.fromLTWH(feet.dx - h * 0.17, feet.dy - h * 0.5, h * 0.34, h * 0.05),
      Paint()..color = MosesColors.robeTrim.withOpacity(0.85),
    );

    // Head, hair, beard.
    final Offset head = Offset(feet.dx, feet.dy - h * 0.86);
    canvas.drawCircle(head, h * 0.115, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: h * 0.125),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFD8D3CE),
    );
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, h * 0.045), radius: h * 0.105),
      0.15,
      math.pi - 0.3,
      true,
      Paint()..color = const Color(0xFFE4E0DB),
    );

    // The arm and staff, raised over the sea. `mosesRaised` drives it, so the
    // gesture is tied to what the water is doing rather than idling.
    final double lift = mosesRaised.clamp(0.0, 1.0);
    final Offset shoulder = Offset(feet.dx + h * 0.13, feet.dy - h * 0.66);
    final Offset hand =
        shoulder + Offset(h * (0.22 + 0.14 * lift), -h * (0.10 + 0.42 * lift));
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = skin
        ..strokeWidth = math.max(2, h * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      hand + Offset(-h * 0.05, h * 0.34),
      hand + Offset(h * 0.05, -h * 0.46),
      Paint()
        ..color = const Color(0xFF6B4A2A)
        ..strokeWidth = math.max(2, h * 0.045)
        ..strokeCap = StrokeCap.round,
    );
    // Light gathering at the staff's tip while he is holding it up.
    if (lift > 0.05) {
      canvas.drawCircle(
        hand + Offset(h * 0.05, -h * 0.46),
        h * 0.16 * lift,
        Paint()
          ..color = MosesColors.blessing.withOpacity(0.55 * lift)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.12),
      );
    }
  }

  void _figure(Canvas canvas, Offset feet, double h, Color robe) {
    if (h < 3) return;
    final Path gown = Path()
      ..moveTo(feet.dx - h * 0.16, feet.dy - h * 0.7)
      ..lineTo(feet.dx + h * 0.16, feet.dy - h * 0.7)
      ..lineTo(feet.dx + h * 0.22, feet.dy)
      ..lineTo(feet.dx - h * 0.22, feet.dy)
      ..close();
    canvas.drawPath(gown, Paint()..color = robe);
    canvas.drawCircle(Offset(feet.dx, feet.dy - h * 0.84), h * 0.16,
        Paint()..color = const Color(0xFFE8C39A));
  }

  // --------------------------------------------------------------- chariots

  /// Chariot silhouettes on the seabed, and their going under.
  ///
  /// Distant silhouettes throughout — no faces, no figures, nothing shown
  /// struggling. As [sink] runs they slide down and the water takes them,
  /// which is as close as this gets to the account's ending.
  void _paintChariots(Canvas canvas, Size size, double horizon) {
    final double scale = _perspective(chariotAdvance);
    final double baseY = _yFor(size, horizon, chariotAdvance);
    final double unit = size.height * 0.105 * scale;
    if (unit < 2) return;

    // Down and away as the water takes them, fading as they go. A deeper
    // drop and a slower fade than the first attempt: they were disappearing
    // almost as soon as they started to move.
    final double drop = sink * size.height * 0.16;
    final double fade = (1 - sink * 0.95).clamp(0.0, 1.0);
    if (fade <= 0) {
      if (sink > 0) _paintSinkFoam(canvas, size, baseY, unit);
      return;
    }

    for (int i = 0; i < kMosesChariots.count; i++) {
      final double lane = kMosesChariots.laneOffsets[i];
      final double x =
          size.width * (0.5 + lane * pathHalfWidth * scale * (1 - sink * 0.3));
      final double jolt = math.sin(phase * 26 + i) * wheelWobble * unit * 0.12;
      // They tip as they go under, at slightly different rates.
      final double tip = sink * (0.5 + i * 0.14);

      canvas.save();
      canvas.translate(x, baseY + drop * (0.8 + i * 0.12) + jolt);
      canvas.rotate(tip);

      final Paint ink = Paint()
        ..color = const Color(0xFF241C16).withOpacity(fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-unit * 0.36, -unit * 0.52, unit * 0.72, unit * 0.42),
          Radius.circular(unit * 0.08),
        ),
        ink,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(unit * 0.30, -unit * 0.60, unit * 0.62, unit * 0.34),
          Radius.circular(unit * 0.14),
        ),
        ink,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(unit * 0.80, -unit * 0.86, unit * 0.20, unit * 0.34),
          Radius.circular(unit * 0.07),
        ),
        ink,
      );
      final double wheelR = unit * 0.24;
      final Offset hub = Offset(-unit * 0.10, -unit * 0.08);
      canvas.drawCircle(
        hub,
        wheelR,
        Paint()
          ..color = const Color(0xFF241C16).withOpacity(fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, unit * 0.07),
      );
      for (int sp = 0; sp < 4; sp++) {
        final double a = sp * math.pi / 2 + phase * (wheelWobble > 0 ? 9 : 3);
        canvas.drawLine(
          hub,
          hub + Offset(math.cos(a) * wheelR, math.sin(a) * wheelR),
          Paint()
            ..color = const Color(0xFF241C16).withOpacity(fade)
            ..strokeWidth = math.max(1, unit * 0.05),
        );
      }
      canvas.restore();

      if (wheelWobble > 0.05 && sink == 0) {
        canvas.drawCircle(
          Offset(x - unit * 0.2, baseY + unit * 0.05),
          unit * 0.3 * wheelWobble,
          Paint()
            ..color = const Color(0xFFCBB79A).withOpacity(0.4 * wheelWobble),
        );
      }
    }

    if (sink > 0) _paintSinkFoam(canvas, size, baseY, unit);
  }

  /// Foam and rings closing over where they were.
  void _paintSinkFoam(Canvas canvas, Size size, double baseY, double unit) {
    final double t = sink;
    for (int i = 0; i < 3; i++) {
      final double r = unit * (0.6 + i * 0.8) * (0.4 + t * 1.6);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * 0.5, baseY),
            width: r * 2.6,
            height: r * 0.7),
        Paint()
          ..color = _crest.withOpacity((0.45 - i * 0.12) * (1 - t * 0.6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, unit * 0.07),
      );
    }
    for (int i = 0; i < 10; i++) {
      final double a = i * math.pi * 2 / 10;
      final double r = unit * (0.5 + t * 1.8);
      canvas.drawCircle(
        Offset(size.width * 0.5 + math.cos(a) * r * 1.5,
            baseY + math.sin(a) * r * 0.4),
        unit * 0.10 * (1 - t) + 1,
        Paint()..color = Colors.white.withOpacity(0.5 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PartedSeaPainter old) => true;
}
