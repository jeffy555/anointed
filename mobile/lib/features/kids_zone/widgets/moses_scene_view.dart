import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../levels/moses_exodus_level.dart';

/// The Nile, painted as a forward-scrolling river seen from behind the basket.
///
/// Unlike the other Kids Zone backdrops this one is not a static scene with a
/// mood — the whole picture is a function of how far the basket has travelled,
/// so the river, the banks and every hazard share one distance axis. That is
/// what keeps "the reeds look close" and "the reeds will hit me" the same fact.

/// Maps a distance ahead of the basket onto the screen.
///
/// Depth runs 0 (level with the basket, at the bottom of the river) to 1 (the
/// horizon). The mapping is deliberately non-linear: real perspective bunches
/// distant things toward the horizon, and without that a hazard appears to
/// *decelerate* as it approaches, which is exactly backwards from how it feels.
class RiverPerspective {
  const RiverPerspective(this.size);

  final Size size;

  /// Where the water meets the sky.
  static const double horizonFraction = 0.32;

  /// Where the basket rides.
  static const double basketFraction = 0.82;

  /// How far ahead the child can see, in metres. Everything beyond this is off
  /// the top of the river. Wider than it needs to be at the slowest stage so
  /// the fastest one still hands over two seconds of runway.
  static const double viewDepth = 30;

  /// How much the lanes converge toward the vanishing point.
  static const double _converge = 0.80;

  double get horizonY => size.height * horizonFraction;
  double get basketY => size.height * basketFraction;

  /// Perspective curve. `_squash(0) == 0`, `_squash(1) == 1`.
  static double _squash(double depth) {
    final double k = depth.clamp(0.0, 1.0);
    return (k / (k + 0.6)) * 1.6;
  }

  /// Screen position of [laneFraction] at [depth].
  Offset project(double laneFraction, double depth) {
    final double t = _squash(depth);
    final double x =
        size.width * (laneFraction + (0.5 - laneFraction) * t * _converge);
    return Offset(x, basketY + (horizonY - basketY) * t);
  }

  /// How large something at [depth] is drawn, relative to the same thing at the
  /// basket.
  double scaleAt(double depth) => 1 - _squash(depth) * 0.88;

  /// Half-width of the river itself at [depth], in pixels.
  double riverHalfWidth(double depth) {
    final double t = _squash(depth);
    return size.width * 0.5 * (1 - t * _converge);
  }
}

/// One thing floating on the river, ready to draw.
class RiverEntityView {
  const RiverEntityView({
    required this.lane,
    required this.depth,
    required this.kind,
    this.lotus = false,
    this.blessing = false,
    this.startled = false,
  });

  final RiverLane lane;

  /// 0 = level with the basket, 1 = at the horizon.
  final double depth;

  /// Null for collectibles.
  final RiverObstacleKind? kind;
  final bool lotus;
  final bool blessing;

  /// A crocodile that has just been bumped wakes up looking surprised.
  final bool startled;
}

/// Everything about how the basket should be drawn this frame.
class RiverBasketView {
  const RiverBasketView({
    required this.laneOffset,
    required this.hop,
    required this.duck,
    required this.tilt,
    required this.shielded,
    required this.bump,
    this.cry = 0,
  });

  /// Continuous lane position: 0 = left lane, 1 = centre, 2 = right. Fractional
  /// while a lane change tweens.
  final double laneOffset;

  /// 0 on the water, 1 at the top of a hop.
  final double hop;

  /// 0 upright, 1 fully ducked.
  final double duck;

  /// Radians; the basket leans into a turn.
  final double tilt;
  final bool shielded;

  /// 1 immediately after a bump, easing back to 0. Drives the splash and the
  /// camera shake — brief, because the collision itself is brief.
  final double bump;

  /// 1 immediately after a heart is lost, easing back to 0 over a few
  /// seconds — deliberately longer than [bump]. A splash reads instantly; a
  /// child's understanding that something just went wrong takes a moment
  /// longer, and the baby's face is what carries that moment.
  final double cry;
}

/// The whole river scene for one frame.
class RiverSceneView extends StatelessWidget {
  const RiverSceneView({
    super.key,
    required this.travelled,
    required this.phase,
    required this.entities,
    required this.basket,
    this.arrival = 0,
    this.speedFactor = 0,
  });

  /// Metres downstream, used to scroll the water and the banks.
  final double travelled;

  /// Free-running seconds, for motion that is not tied to travel (sun glint,
  /// the princess's wave).
  final double phase;

  final List<RiverEntityView> entities;
  final RiverBasketView basket;

  /// 0 while running; ramps to 1 across the princess arrival beat.
  final double arrival;

  /// How fast the river feels right now: 0 at a stop, 1 at a stage's usual
  /// top speed, higher while boosting. Drives the speed-streak overlay.
  final double speedFactor;

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RiverScenePainter(
          travelled: travelled,
          phase: phase,
          entities: entities,
          basket: basket,
          arrival: arrival,
          speedFactor: speedFactor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RiverScenePainter extends CustomPainter {
  _RiverScenePainter({
    required this.travelled,
    required this.phase,
    required this.entities,
    required this.basket,
    required this.arrival,
    required this.speedFactor,
  });

  final double travelled;
  final double phase;
  final List<RiverEntityView> entities;
  final RiverBasketView basket;
  final double arrival;
  final double speedFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final RiverPerspective p = RiverPerspective(size);
    canvas.clipRect(Offset.zero & size);

    // A bump kicks the whole camera, not just the basket — a Temple-Run-style
    // hit reaction rather than a prop wobbling on an otherwise static screen.
    // Deterministic (sine-based, not `Random`) so the same frame always paints
    // the same way, which is what keeps this paintable in a golden test.
    final Offset shake = basket.bump > 0.02
        ? Offset(
            math.sin(phase * 41) * basket.bump * 6,
            math.cos(phase * 37) * basket.bump * 4,
          )
        : Offset.zero;

    // The camera leans into a lane change the way a runner's does, banking
    // around the point where the river vanishes rather than the screen's
    // centre — that keeps the horizon itself from swinging, only the lanes.
    final double lean = basket.tilt * 0.24;
    final Offset pivot = Offset(size.width / 2, p.horizonY);

    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(lean);
    canvas.translate(-pivot.dx, -pivot.dy);

    _paintSky(canvas, size, p);
    _paintBanks(canvas, size, p);
    _paintRiver(canvas, size, p);

    // Back to front, so a near hazard overlaps a far one rather than the
    // reverse — the single most important cue for "which one hits me first".
    final List<RiverEntityView> ordered = entities.toList()
      ..sort(
          (RiverEntityView a, RiverEntityView b) => b.depth.compareTo(a.depth));
    for (final RiverEntityView e in ordered) {
      _paintEntity(canvas, p, e);
    }

    if (arrival > 0) _paintPrincess(canvas, size, p);
    _paintBasket(canvas, size, p);
    canvas.restore();

    // Speed streaks sit outside the leaning/shaking transform — they are the
    // screen's own reaction to velocity, not part of the world, the way a
    // camera's motion blur is a lens effect rather than something happening
    // to the road.
    if (speedFactor > 0.72) _paintSpeedStreaks(canvas, size, p);
  }

  void _paintSpeedStreaks(Canvas canvas, Size size, RiverPerspective p) {
    final double intensity =
        ((speedFactor - 0.72) / (1.4 - 0.72)).clamp(0.0, 1.0);
    final Offset vanishing = Offset(size.width * 0.5, p.horizonY);
    final double maxReach = size.longestSide * 0.62;
    const int streakCount = 12;

    for (int i = 0; i < streakCount; i++) {
      final double angle =
          (i / streakCount) * math.pi * 2 + phase * 0.12 + i * 0.37;
      final Offset dir = Offset(math.cos(angle), math.sin(angle));
      // Skip streaks that would shoot up into open sky — they read as noise
      // rather than speed when there is nothing there to be streaking past.
      if (dir.dy < -0.55) continue;

      final double innerR = size.shortestSide * 0.16;
      final double outerR = innerR +
          maxReach *
              intensity *
              (0.55 + 0.45 * (0.5 + 0.5 * math.sin(i * 2.1 + phase * 1.6)));
      final Offset start = vanishing + dir * innerR;
      final Offset end = vanishing + dir * outerR;

      canvas.drawLine(
        start,
        end,
        Paint()
          // Point-to-point, not rect-based: a rect-aligned gradient would fade
          // along the wrong axis for anything but a horizontal streak.
          ..shader = ui.Gradient.linear(
            start,
            end,
            <Color>[
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.32 * intensity),
            ],
          )
          ..strokeWidth = 1.4 + 1.8 * intensity
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ------------------------------------------------------------------- sky

  void _paintSky(Canvas canvas, Size size, RiverPerspective p) {
    final Rect sky = Rect.fromLTWH(0, 0, size.width, p.horizonY + 1);
    canvas.drawRect(
      sky,
      Paint()..shader = MosesColors.skyGradient.createShader(sky),
    );

    // Sun low over the water, with a glint that breathes.
    final double glint = 0.5 + 0.5 * math.sin(phase * 0.9);
    final Offset sun = Offset(size.width * 0.74, p.horizonY * 0.42);
    canvas.drawCircle(
      sun,
      size.width * (0.075 + 0.006 * glint),
      Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.85),
    );
    canvas.drawCircle(
      sun,
      size.width * 0.16,
      Paint()
        ..color = const Color(0xFFFFE1A0).withOpacity(0.18 + 0.06 * glint)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );

    // Far palms on the horizon — parallax at a tenth of the river's speed, so
    // the distance reads as distance.
    final double drift = (travelled * 0.1) % (size.width * 0.5);
    for (int i = -1; i < 5; i++) {
      final double x = i * size.width * 0.5 - drift + size.width * 0.08;
      _paintPalm(canvas, Offset(x, p.horizonY), size.width * 0.05, 0.35);
      _paintPalm(canvas, Offset(x + size.width * 0.26, p.horizonY),
          size.width * 0.038, 0.28);
    }
  }

  void _paintPalm(Canvas canvas, Offset base, double height, double opacity) {
    final Paint paint = Paint()
      ..color = MosesColors.reedDark.withOpacity(opacity);
    canvas.drawRect(
      Rect.fromLTWH(
          base.dx - height * 0.05, base.dy - height, height * 0.1, height),
      paint,
    );
    for (int i = 0; i < 5; i++) {
      final double a = -math.pi / 2 + (i - 2) * 0.55;
      final Path frond = Path()
        ..moveTo(base.dx, base.dy - height)
        ..quadraticBezierTo(
          base.dx + math.cos(a) * height * 0.34,
          base.dy - height + math.sin(a) * height * 0.34,
          base.dx + math.cos(a) * height * 0.55,
          base.dy - height + math.sin(a) * height * 0.55 + height * 0.1,
        );
      canvas.drawPath(
        frond,
        Paint()
          ..color = MosesColors.reedDark.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = height * 0.09
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ----------------------------------------------------------------- banks

  void _paintBanks(Canvas canvas, Size size, RiverPerspective p) {
    final Paint sand = Paint()..color = MosesColors.sand;
    canvas.drawRect(
      Rect.fromLTWH(0, p.horizonY, size.width, size.height - p.horizonY),
      sand,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, p.horizonY, size.width, size.height * 0.06),
      Paint()..color = MosesColors.sandDark.withOpacity(0.45),
    );

    // Papyrus down both banks. Spaced in metres so they stream past at exactly
    // the river's speed.
    const double spacing = 4.0;
    final double first = travelled - (travelled % spacing);
    for (int i = 0; i < 14; i++) {
      final double metres = first + i * spacing;
      final double depth = (metres - travelled) / RiverPerspective.viewDepth;
      if (depth < -0.05 || depth > 1) continue;
      final double scale = p.scaleAt(depth.clamp(0.0, 1.0));
      final double sway =
          math.sin(phase * 1.4 + metres * 0.7) * size.width * 0.012 * scale;
      for (final double side in <double>[-1, 1]) {
        final Offset root = p.project(0.5 + side * 0.62, depth.clamp(0.0, 1.0));
        _paintReedTuft(
          canvas,
          Offset(root.dx + sway, root.dy),
          size.height * 0.24 * scale,
          MosesColors.reed,
        );
      }
    }
  }

  void _paintReedTuft(Canvas canvas, Offset base, double height, Color color) {
    if (height <= 1) return;
    for (int i = -2; i <= 2; i++) {
      final double lean = i * 0.14;
      final Offset tip = Offset(
        base.dx + lean * height * 0.5,
        base.dy - height * (1 - (i.abs() * 0.14)),
      );
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = color.withOpacity(0.9)
          ..strokeWidth = math.max(1, height * 0.055)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        tip,
        math.max(1, height * 0.075),
        Paint()..color = MosesColors.reedLight.withOpacity(0.85),
      );
    }
  }

  // ----------------------------------------------------------------- river

  void _paintRiver(Canvas canvas, Size size, RiverPerspective p) {
    final Path river = Path()
      ..moveTo(size.width * 0.5 - p.riverHalfWidth(1), p.horizonY)
      ..lineTo(size.width * 0.5 + p.riverHalfWidth(1), p.horizonY)
      ..lineTo(size.width * 0.5 + p.riverHalfWidth(0), size.height)
      ..lineTo(size.width * 0.5 - p.riverHalfWidth(0), size.height)
      ..close();

    canvas.save();
    canvas.clipPath(river);
    canvas.drawPaint(Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          MosesColors.waterLight,
          MosesColors.water,
          MosesColors.waterDeep
        ],
        stops: <double>[0.0, 0.45, 1.0],
      ).createShader(
          Rect.fromLTWH(0, p.horizonY, size.width, size.height - p.horizonY)));

    // Current lines streaming toward the viewer. Same metre spacing as the
    // reeds, so the water and the banks agree about how fast the river runs.
    const double bandSpacing = 2.0;
    final double firstBand = travelled - (travelled % bandSpacing);
    for (int i = 0; i < 22; i++) {
      final double metres = firstBand + i * bandSpacing;
      final double depth =
          ((metres - travelled) / RiverPerspective.viewDepth).clamp(0.0, 1.0);
      final Offset l = p.project(0.5 - 0.5, depth);
      final Offset r = p.project(0.5 + 0.5, depth);
      canvas.drawLine(
        l,
        r,
        Paint()
          ..color = MosesColors.foam.withOpacity(0.06 + 0.10 * (1 - depth))
          ..strokeWidth = math.max(1, 3.5 * p.scaleAt(depth)),
      );
    }

    // Lane seams — faint, but enough that a child can see three lanes rather
    // than one wide river.
    for (final double seam in <double>[0.375, 0.625]) {
      canvas.drawLine(
        p.project(seam, 0),
        p.project(seam, 1),
        Paint()
          ..color = MosesColors.foam.withOpacity(0.12)
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
  }

  // -------------------------------------------------------------- entities

  void _paintEntity(Canvas canvas, RiverPerspective p, RiverEntityView e) {
    final Offset at = p.project(e.lane.fraction, e.depth);
    final double scale = p.scaleAt(e.depth);
    final double unit = p.size.width * 0.20 * scale;
    if (unit <= 1) return;

    if (e.lotus) {
      _paintLotus(canvas, at, unit * 0.42);
      return;
    }
    if (e.blessing) {
      _paintBlessing(canvas, at, unit * 0.55);
      return;
    }

    switch (e.kind!) {
      case RiverObstacleKind.reedCluster:
        _paintReedTuft(canvas, at, unit * 1.9, MosesColors.reedDark);
        _paintReedTuft(
            canvas, at.translate(unit * 0.18, 0), unit * 1.5, MosesColors.reed);
      case RiverObstacleKind.reedVine:
        _paintVine(canvas, at, unit);
      case RiverObstacleKind.floatingLog:
        _paintLog(canvas, at, unit);
      case RiverObstacleKind.sleepyCrocodile:
        _paintCrocodile(canvas, at, unit, e.startled);
    }
  }

  void _paintLotus(Canvas canvas, Offset at, double r) {
    final double bob = math.sin(phase * 3 + at.dx * 0.05) * r * 0.12;
    final Offset c = at.translate(0, bob - r * 0.2);
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(math.cos(a) * r * 0.5, math.sin(a) * r * 0.3),
          width: r * 0.9,
          height: r * 0.55,
        ),
        Paint()..color = MosesColors.lotus,
      );
    }
    canvas.drawCircle(c, r * 0.32, Paint()..color = MosesColors.lotusHeart);
  }

  void _paintBlessing(Canvas canvas, Offset at, double r) {
    final double shimmer = 0.6 + 0.4 * math.sin(phase * 4 + at.dy * 0.03);
    canvas.drawCircle(
      at,
      r * 1.5,
      Paint()
        ..color = MosesColors.blessing.withOpacity(0.35 * shimmer)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );
    // A single descending feather, not a coin: this is mercy arriving, and it
    // should not read as something to score.
    final Path feather = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx + r * 0.7, at.dy - r * 0.1, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx - r * 0.7, at.dy - r * 0.1, at.dx, at.dy - r)
      ..close();
    canvas.drawPath(feather, Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawLine(
      Offset(at.dx, at.dy - r * 0.8),
      Offset(at.dx, at.dy + r * 0.85),
      Paint()
        ..color = MosesColors.blessing
        ..strokeWidth = math.max(1, r * 0.14),
    );
  }

  void _paintVine(Canvas canvas, Offset at, double unit) {
    // Hangs from above and arches across the lane, leaving clear water below —
    // the picture has to say "go under me" before the child has to know it.
    final Rect span = Rect.fromCenter(
      center: at.translate(0, -unit * 1.55),
      width: unit * 1.9,
      height: unit * 0.9,
    );
    final Path arch = Path()
      ..moveTo(span.left, span.top - unit * 0.5)
      ..quadraticBezierTo(
          span.center.dx, span.bottom, span.right, span.top - unit * 0.5);
    canvas.drawPath(
      arch,
      Paint()
        ..color = MosesColors.reedDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, unit * 0.16)
        ..strokeCap = StrokeCap.round,
    );
    for (int i = 0; i < 5; i++) {
      final double t = i / 4;
      final double x = span.left + span.width * t;
      final double droop =
          span.bottom - (t - 0.5) * (t - 0.5) * span.height * 4 * 0.5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, droop - unit * 0.1),
          width: unit * 0.34,
          height: unit * 0.5,
        ),
        Paint()..color = MosesColors.reed,
      );
    }
  }

  void _paintLog(Canvas canvas, Offset at, double unit) {
    final double bob = math.sin(phase * 2.2 + at.dx * 0.04) * unit * 0.05;
    final Rect body = Rect.fromCenter(
      center: at.translate(0, bob - unit * 0.12),
      width: unit * 1.7,
      height: unit * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(body.height / 2)),
      Paint()..color = MosesColors.basketDark,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(body.right - body.height * 0.28, body.center.dy),
        width: body.height * 0.55,
        height: body.height * 0.9,
      ),
      Paint()..color = MosesColors.basket,
    );
    // Waterline, so it reads as floating low rather than standing tall.
    canvas.drawLine(
      Offset(body.left, body.bottom),
      Offset(body.right, body.bottom),
      Paint()
        ..color = MosesColors.foam.withOpacity(0.5)
        ..strokeWidth = math.max(1, unit * 0.08),
    );
  }

  /// A real crocodile floats low, drifts, and its tail sways even at rest —
  /// stillness is what read as a painted log rather than an animal. It is
  /// still asleep, still calm, and its jaws never open: motion is what makes
  /// it feel alive, not what makes it a threat.
  void _paintCrocodile(Canvas canvas, Offset at, double unit, bool startled) {
    final double bob = math.sin(phase * 1.4 + at.dx * 0.03) * unit * 0.045;
    final Offset c = at.translate(0, bob - unit * 0.1);

    final double bodyLen = unit * 1.55;
    final double bodyH = unit * 0.46;
    final Offset snoutJoin = Offset(c.dx - bodyLen * 0.42, c.dy);
    final Offset tailJoin = Offset(c.dx + bodyLen * 0.4, c.dy);

    // A torpedo-shaped torso — wider through the shoulders than a plain
    // rounded rect gives, and narrower at both the snout and the tail joint,
    // which is what a rounded-rect silhouette can't say by itself.
    final Path torso = Path()
      ..moveTo(snoutJoin.dx, snoutJoin.dy - bodyH * 0.32)
      ..quadraticBezierTo(c.dx - bodyLen * 0.1, c.dy - bodyH * 0.62,
          c.dx + bodyLen * 0.12, c.dy - bodyH * 0.5)
      ..quadraticBezierTo(tailJoin.dx - unit * 0.05, c.dy - bodyH * 0.28,
          tailJoin.dx, tailJoin.dy)
      ..quadraticBezierTo(tailJoin.dx - unit * 0.05, c.dy + bodyH * 0.4,
          c.dx + bodyLen * 0.1, c.dy + bodyH * 0.46)
      ..quadraticBezierTo(c.dx - bodyLen * 0.12, c.dy + bodyH * 0.56,
          snoutJoin.dx, snoutJoin.dy + bodyH * 0.3)
      ..close();
    canvas.drawPath(torso, Paint()..color = MosesColors.croc);
    // A darker belly-line shadow reads as the waterline it floats at.
    canvas.drawPath(
      torso,
      Paint()
        ..color = MosesColors.crocDark.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Scutes along the back, continuing partway onto the tail so the ridge
    // doesn't stop abruptly where the torso does.
    for (int i = 0; i < 5; i++) {
      final double x = snoutJoin.dx + bodyLen * (0.28 + i * 0.13);
      final double topY = c.dy - bodyH * (0.55 - (i - 2).abs() * 0.03);
      final Path bump = Path()
        ..moveTo(x - unit * 0.08, topY + unit * 0.1)
        ..lineTo(x, topY - unit * 0.1)
        ..lineTo(x + unit * 0.08, topY + unit * 0.1)
        ..close();
      canvas.drawPath(bump, Paint()..color = MosesColors.crocDark);
    }

    // The tail swishes from the torso joint — a slow drifting swim, never a
    // thrash. Painted first so the torso's tail-join edge overlaps it.
    final double swish = math.sin(phase * 1.1 + at.dx * 0.02) * 0.22;
    canvas.save();
    canvas.translate(tailJoin.dx, tailJoin.dy);
    canvas.rotate(swish);
    final Path tail = Path()
      ..moveTo(0, -bodyH * 0.4)
      ..quadraticBezierTo(unit * 0.5, -bodyH * 0.22, unit * 0.95, -unit * 0.04)
      ..quadraticBezierTo(unit * 1.05, 0, unit * 0.95, unit * 0.04)
      ..quadraticBezierTo(unit * 0.5, bodyH * 0.22, 0, bodyH * 0.42)
      ..close();
    canvas.drawPath(tail, Paint()..color = MosesColors.croc);
    for (int i = 0; i < 3; i++) {
      final double x = unit * (0.32 + i * 0.24);
      canvas.drawLine(
        Offset(x, -bodyH * 0.28 + i * unit * 0.02),
        Offset(x, bodyH * 0.28 - i * unit * 0.02),
        Paint()
          ..color = MosesColors.crocDark.withOpacity(0.6)
          ..strokeWidth = math.max(1, unit * 0.03),
      );
    }
    canvas.restore();

    // Two small webbed feet, paddling gently out of phase with each other —
    // a real crocodile floats with its legs doing slow, lazy work even while
    // the rest of it looks perfectly still.
    for (int i = 0; i < 2; i++) {
      final double footPhase = phase * 1.6 + i * math.pi;
      final double footBob = math.sin(footPhase) * unit * 0.05;
      final Offset foot = Offset(
        c.dx - bodyLen * (0.05 - i * 0.32),
        c.dy + bodyH * 0.5 + footBob,
      );
      final Path web = Path()
        ..moveTo(foot.dx - unit * 0.09, foot.dy)
        ..lineTo(foot.dx - unit * 0.03, foot.dy + unit * 0.12)
        ..lineTo(foot.dx + unit * 0.03, foot.dy + unit * 0.12)
        ..lineTo(foot.dx + unit * 0.09, foot.dy)
        ..close();
      canvas.drawPath(
          web, Paint()..color = MosesColors.crocDark.withOpacity(0.85));
    }

    // Snout: tapered rather than a blunt rounded rect, with a raised brow
    // ridge and two nostril bumps at the very tip — the two features that
    // read as "crocodile" rather than "green log" at a glance. Jaws stay
    // shut in every state.
    final Offset snoutTip =
        Offset(snoutJoin.dx - unit * 0.62, snoutJoin.dy + unit * 0.01);
    final Path snout = Path()
      ..moveTo(snoutJoin.dx, snoutJoin.dy - bodyH * 0.3)
      ..quadraticBezierTo(snoutJoin.dx - unit * 0.4, snoutJoin.dy - bodyH * 0.2,
          snoutTip.dx, snoutTip.dy - unit * 0.07)
      ..quadraticBezierTo(snoutTip.dx - unit * 0.05, snoutTip.dy, snoutTip.dx,
          snoutTip.dy + unit * 0.07)
      ..quadraticBezierTo(snoutJoin.dx - unit * 0.4,
          snoutJoin.dy + bodyH * 0.24, snoutJoin.dx, snoutJoin.dy + bodyH * 0.3)
      ..close();
    canvas.drawPath(snout, Paint()..color = MosesColors.croc);
    canvas.drawPath(
      snout,
      Paint()
        ..color = MosesColors.crocDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, unit * 0.025),
    );
    // The closed jaw line down the length of the snout.
    canvas.drawLine(
      Offset(snoutJoin.dx - unit * 0.06, snoutJoin.dy + unit * 0.01),
      Offset(snoutTip.dx + unit * 0.06, snoutTip.dy),
      Paint()
        ..color = MosesColors.crocDark.withOpacity(0.7)
        ..strokeWidth = math.max(1, unit * 0.025),
    );
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(snoutTip.dx + unit * 0.06, snoutTip.dy + side * unit * 0.045),
        unit * 0.02,
        Paint()..color = MosesColors.crocDark,
      );
    }

    // A brow ridge above the eye — the raised bump a real crocodile has,
    // rather than an eye sitting flush on a smooth head.
    final Offset eye =
        Offset(snoutJoin.dx + unit * 0.18, snoutJoin.dy - bodyH * 0.34);
    canvas.drawOval(
      Rect.fromCenter(
          center: eye.translate(0, -unit * 0.07),
          width: unit * 0.26,
          height: unit * 0.1),
      Paint()..color = MosesColors.crocDark.withOpacity(0.55),
    );

    if (startled) {
      canvas.drawCircle(eye, unit * 0.11, Paint()..color = Colors.white);
      canvas.drawCircle(eye, unit * 0.05, Paint()..color = MosesColors.ink);
      // A little "!" of surprise — the joke is on the crocodile.
      final double x = tailJoin.dx + unit * 0.22;
      canvas.drawLine(
        Offset(x, c.dy - unit * 0.55),
        Offset(x, c.dy - unit * 0.22),
        Paint()
          ..color = Colors.white
          ..strokeWidth = math.max(1.5, unit * 0.1)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(x, c.dy - unit * 0.08), unit * 0.055,
          Paint()..color = Colors.white);
    } else {
      // Closed eye: a simple shut lid, plus drifting snore bubbles.
      canvas.drawArc(
        Rect.fromCenter(center: eye, width: unit * 0.2, height: unit * 0.16),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = MosesColors.crocDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, unit * 0.055),
      );
      for (int i = 0; i < 3; i++) {
        final double t = ((phase * 0.5 + i * 0.33) % 1);
        canvas.drawCircle(
          Offset(snoutJoin.dx - unit * 0.5 - t * unit * 0.4,
              c.dy - unit * 0.35 - t * unit * 0.6),
          unit * 0.07 * (1 - t) + 1,
          Paint()..color = Colors.white.withOpacity(0.5 * (1 - t)),
        );
      }
    }
  }

  // -------------------------------------------------------------- princess

  void _paintPrincess(Canvas canvas, Size size, RiverPerspective p) {
    final double t = arrival.clamp(0.0, 1.0);
    // Walks in from the bank as the basket drifts over.
    final double depth = 0.30 - 0.12 * t;
    final Offset feet = p.project(0.93, depth);
    final double unit = size.width * 0.22 * p.scaleAt(depth);
    final double fade = (t * 2.2).clamp(0.0, 1.0);

    final Paint robe = Paint()..color = MosesColors.robe.withOpacity(fade);
    final Path gown = Path()
      ..moveTo(feet.dx - unit * 0.38, feet.dy)
      ..lineTo(feet.dx - unit * 0.16, feet.dy - unit * 1.15)
      ..lineTo(feet.dx + unit * 0.16, feet.dy - unit * 1.15)
      ..lineTo(feet.dx + unit * 0.38, feet.dy)
      ..close();
    canvas.drawPath(gown, robe);
    canvas.drawRect(
      Rect.fromLTWH(feet.dx - unit * 0.34, feet.dy - unit * 0.16, unit * 0.68,
          unit * 0.1),
      Paint()..color = MosesColors.robeTrim.withOpacity(fade),
    );
    canvas.drawCircle(
      Offset(feet.dx, feet.dy - unit * 1.34),
      unit * 0.22,
      Paint()..color = const Color(0xFFE8C39A).withOpacity(fade),
    );
    // Head-dress, so she reads as the princess and not a passer-by.
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(feet.dx, feet.dy - unit * 1.34), radius: unit * 0.27),
      math.pi,
      math.pi,
      true,
      Paint()..color = MosesColors.robeTrim.withOpacity(fade),
    );

    // A slow wave — the only motion in the beat, so the eye goes to it.
    final double wave = math.sin(phase * 3) * 0.5;
    final Offset shoulder = Offset(feet.dx - unit * 0.16, feet.dy - unit * 1.0);
    final Offset hand = shoulder +
        Offset(-unit * 0.42 * math.cos(wave), -unit * 0.42 * (1 + wave * 0.3));
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = const Color(0xFFE8C39A).withOpacity(fade)
        ..strokeWidth = math.max(2, unit * 0.13)
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------- basket

  void _paintBasket(Canvas canvas, Size size, RiverPerspective p) {
    // Lane 0..2 maps onto the same fractions the hazards use, so "same lane"
    // is the same number on screen as it is in the collision check.
    final double fraction = 0.25 + basket.laneOffset * 0.25;
    final Offset seat = p.project(fraction, 0);
    final double unit = size.width * 0.22;

    final double hopLift = basket.hop * unit * 0.85;
    final double squash = basket.duck * 0.34 + basket.bump * 0.18;
    final Offset centre = seat.translate(0, -unit * 0.18 - hopLift);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(basket.tilt);
    canvas.scale(1 + squash * 0.5, 1 - squash);

    // Shadow / wake on the water, which grows apart from the basket during a
    // hop — the gap is what makes the hop legible.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, unit * 0.34 + hopLift * 0.9),
        width: unit * (0.95 - basket.hop * 0.25),
        height: unit * 0.18,
      ),
      Paint()..color = MosesColors.waterDeep.withOpacity(0.28),
    );

    if (basket.shielded) {
      final double pulse = 0.7 + 0.3 * math.sin(phase * 6);
      canvas.drawCircle(
        Offset.zero,
        unit * 0.78,
        Paint()
          ..color = MosesColors.blessing.withOpacity(0.30 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        Offset.zero,
        unit * 0.62,
        Paint()
          ..color = MosesColors.blessing.withOpacity(0.85 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    final Rect hull = Rect.fromCenter(
      center: Offset.zero,
      width: unit * 0.92,
      height: unit * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hull, Radius.circular(unit * 0.2)),
      Paint()..color = MosesColors.basket,
    );
    // Weave.
    for (int i = 1; i < 5; i++) {
      final double x = hull.left + hull.width * i / 5;
      canvas.drawLine(
        Offset(x, hull.top + 2),
        Offset(x, hull.bottom - 2),
        Paint()
          ..color = MosesColors.basketDark.withOpacity(0.45)
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawLine(
      Offset(hull.left + 3, hull.center.dy),
      Offset(hull.right - 3, hull.center.dy),
      Paint()
        ..color = MosesColors.basketDark.withOpacity(0.45)
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, hull.top),
            width: unit * 0.98,
            height: unit * 0.14),
        Radius.circular(unit * 0.07),
      ),
      Paint()..color = MosesColors.basketLight,
    );

    // Swaddling cloth and the baby — visible, safe, never in peril. Asleep
    // ordinarily; startled into tears for a few seconds right after a bump,
    // because a bump that never changed the baby's face would read as the
    // baby not having noticed, which undersells why the child should care.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -unit * 0.06),
          width: unit * 0.5,
          height: unit * 0.2),
      Paint()..color = MosesColors.cloth,
    );
    _paintBabyFace(
        canvas, Offset(unit * 0.13, -unit * 0.09), unit * 0.075, basket.cry);
    canvas.restore();

    if (basket.bump > 0.05) {
      _paintSplash(canvas, seat, unit, basket.bump);
    }
  }

  void _paintBabyFace(Canvas canvas, Offset head, double r, double cry) {
    canvas.drawCircle(head, r, Paint()..color = const Color(0xFFE8C39A));
    if (cry <= 0.04) {
      // Asleep: two closed-eye lashes and a small content mouth line.
      for (final double side in <double>[-1, 1]) {
        canvas.drawLine(
          head.translate(side * r * 0.32 - r * 0.12, -r * 0.05),
          head.translate(side * r * 0.32 + r * 0.12, -r * 0.05),
          Paint()
            ..color = MosesColors.ink.withOpacity(0.55)
            ..strokeWidth = math.max(0.6, r * 0.09)
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawArc(
        Rect.fromCenter(
            center: head.translate(0, r * 0.32),
            width: r * 0.5,
            height: r * 0.3),
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = MosesColors.ink.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.08),
      );
      return;
    }

    // Crying: scrunched brows, an open wailing mouth, and tears that fall and
    // fade — eases out with `cry` so the moment settles rather than snapping
    // back to sleep the instant the timer runs out.
    for (final double side in <double>[-1, 1]) {
      canvas.drawLine(
        head.translate(side * r * 0.42, -r * 0.28),
        head.translate(side * r * 0.16, -r * 0.4),
        Paint()
          ..color = MosesColors.ink.withOpacity(0.6 * cry)
          ..strokeWidth = math.max(0.6, r * 0.1)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: head.translate(0, r * 0.32),
        width: r * (0.38 + 0.1 * cry),
        height: r * (0.42 + 0.18 * cry),
      ),
      Paint()..color = MosesColors.ink.withOpacity(0.75 * cry),
    );
    for (final double side in <double>[-1, 1]) {
      final double drop = ((phase * 1.8 + (side > 0 ? 0.5 : 0)) % 1) * cry;
      canvas.drawOval(
        Rect.fromCenter(
          center: head.translate(side * r * 0.55, -r * 0.05 + drop * r * 0.9),
          width: r * 0.14,
          height: r * 0.22,
        ),
        Paint()..color = MosesColors.water.withOpacity((1 - drop) * cry),
      );
    }
  }

  void _paintSplash(Canvas canvas, Offset seat, double unit, double t) {
    final double r = unit * (0.35 + 0.55 * (1 - t));
    canvas.drawCircle(
      seat.translate(0, unit * 0.1),
      r,
      Paint()
        ..color = MosesColors.foam.withOpacity(0.55 * t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, unit * 0.06 * t),
    );
    for (int i = 0; i < 7; i++) {
      final double a = i * math.pi * 2 / 7 - math.pi / 2;
      canvas.drawCircle(
        seat.translate(math.cos(a) * r, unit * 0.1 + math.sin(a) * r * 0.45),
        unit * 0.05 * t + 1,
        Paint()..color = MosesColors.foam.withOpacity(0.7 * t),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RiverScenePainter old) => true;
}
