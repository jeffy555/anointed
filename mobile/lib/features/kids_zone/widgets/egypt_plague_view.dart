import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/moses_exodus_level.dart';

/// Egypt, reacting.
///
/// Every other Kids Zone level has a scene that changes as the child plays —
/// the Ark grows, the Creation world fills, the river runs. Plague Sort would
/// otherwise be cards on a flat background, with a correct placement animating
/// only the card itself and nothing in the world answering it. This backdrop
/// closes that gap: each correct placement makes something happen *to Egypt*,
/// so the level reads as causing the ten plagues in order rather than sorting
/// ten pictures.
///
/// Effects are brief (about 1.8s) and clear the frame afterwards. Two things
/// persist deliberately: the river stays red once blood is placed, and the
/// greenery stays gone once the locusts have been — those are the two the
/// story itself does not undo. Everything else passes, so the scene stays
/// legible instead of silting up.
class EgyptPlagueView extends StatefulWidget {
  const EgyptPlagueView({
    super.key,
    required this.effect,
    required this.placed,
    this.crownFallen = false,
  });

  /// The effect currently playing, or null between placements.
  final PlagueEffect? effect;

  /// Every effect placed so far, for the state that persists.
  final Set<PlagueEffect> placed;

  /// Pharaoh's crown has come off the roof and stays off.
  final bool crownFallen;

  @override
  State<EgyptPlagueView> createState() => _EgyptPlagueViewState();
}

class _EgyptPlagueViewState extends State<EgyptPlagueView>
    with TickerProviderStateMixin {
  /// Ambient life — guards breathing, water moving — so the scene is alive
  /// before the child has placed anything at all.
  late final AnimationController _loop;

  /// Runs once per placement, 0 → 1 across the effect's whole life.
  late final AnimationController _effect;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _effect = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.effect != null) _effect.forward(from: 0);
  }

  @override
  void didUpdateWidget(EgyptPlagueView old) {
    super.didUpdateWidget(old);
    // Restart on every new placement, including the same effect twice, so a
    // replayed beat still plays rather than sitting finished.
    if (widget.effect != null && widget.effect != old.effect) {
      _effect.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _effect.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_loop, _effect]),
        builder: (BuildContext context, _) {
          return CustomPaint(
            painter: _EgyptPainter(
              effect: widget.effect,
              placed: widget.placed,
              crownFallen: widget.crownFallen,
              progress: _loop.value,
              // Held at 0 once an effect has finished, so a spent effect stops
              // drawing instead of freezing on its last frame.
              t: _effect.isAnimating || _effect.value < 1 ? _effect.value : 0,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _EgyptPainter extends CustomPainter {
  _EgyptPainter({
    required this.effect,
    required this.placed,
    required this.crownFallen,
    required this.progress,
    required this.t,
  });

  final PlagueEffect? effect;
  final Set<PlagueEffect> placed;
  final bool crownFallen;

  /// Ambient loop, 0..1.
  final double progress;

  /// The current effect's own progress, 0..1. 0 means nothing is playing.
  final double t;

  bool get _playing => effect != null && t > 0 && t < 1;

  /// Eases in and back out, so an effect arrives and leaves rather than
  /// snapping off mid-frame.
  double get _pulse => _playing ? math.sin(t * math.pi) : 0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    final double horizon = size.height * 0.62;
    // Darkness dims the whole scene, so it is applied as a layer over
    // everything rather than by re-colouring each element.
    final double dim = effect == PlagueEffect.darkness ? _pulse * 0.82 : 0;

    _paintSky(canvas, size, horizon);
    _paintPalace(canvas, size, horizon);
    _paintCourtyard(canvas, size, horizon);
    if (!placed.contains(PlagueEffect.locusts) ||
        effect == PlagueEffect.locusts) {
      _paintGreenery(canvas, size, horizon);
    }
    _paintGuards(canvas, size, horizon);
    _paintCattle(canvas, size, horizon);
    _paintRiver(canvas, size, horizon);
    _paintCrown(canvas, size, horizon);

    if (_playing) _paintEffect(canvas, size, horizon);

    if (dim > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF0B1020).withOpacity(dim),
      );
    }
  }

  // ------------------------------------------------------------------ world

  void _paintSky(Canvas canvas, Size size, double horizon) {
    final Rect sky = Rect.fromLTWH(0, 0, size.width, horizon);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF8ECAE6),
            Color(0xFFCFE3E0),
            MosesColors.skyLow
          ],
        ).createShader(sky),
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, horizon * 0.28),
      size.width * 0.05,
      Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.9),
    );
  }

  void _paintPalace(Canvas canvas, Size size, double horizon) {
    final double w = size.width * 0.44;
    final Rect body = Rect.fromLTWH(size.width * 0.5 - w / 2,
        horizon - size.height * 0.40, w, size.height * 0.40);
    canvas.drawRect(body, Paint()..color = const Color(0xFFD9C39A));
    canvas.drawRect(
      Rect.fromLTWH(body.left, body.top, body.width, size.height * 0.035),
      Paint()..color = const Color(0xFFC0A87E),
    );
    // Columns and windows — the windows matter, the flies swarm at them.
    for (int i = 0; i < 4; i++) {
      final double x = body.left + body.width * (0.12 + i * 0.25);
      canvas.drawRect(
        Rect.fromLTWH(x, body.top + size.height * 0.05, body.width * 0.06,
            body.height - size.height * 0.05),
        Paint()..color = const Color(0xFFEADCBC),
      );
    }
    for (final Offset w0 in _windowSpots(size, horizon)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: w0,
              width: size.width * 0.035,
              height: size.height * 0.05),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF6B5B44),
      );
    }
    // Steps down to the courtyard.
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
            body.left - size.width * 0.02 * (i + 1),
            horizon + size.height * 0.012 * i,
            body.width + size.width * 0.04 * (i + 1),
            size.height * 0.014),
        Paint()
          ..color = Color.lerp(
              const Color(0xFFD9C39A), const Color(0xFFB59B71), i / 3)!,
      );
    }
  }

  List<Offset> _windowSpots(Size size, double horizon) => <Offset>[
        Offset(size.width * 0.40, horizon - size.height * 0.30),
        Offset(size.width * 0.50, horizon - size.height * 0.30),
        Offset(size.width * 0.60, horizon - size.height * 0.30),
      ];

  void _paintCourtyard(Canvas canvas, Size size, double horizon) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()..color = MosesColors.sand,
    );
  }

  void _paintGreenery(Canvas canvas, Size size, double horizon) {
    // Palms either side. The locusts take these away, and they stay gone.
    final double fade = effect == PlagueEffect.locusts ? 1 - _pulse : 1;
    for (final double x in <double>[0.12, 0.88]) {
      final Offset base = Offset(size.width * x, horizon + size.height * 0.02);
      final double h = size.height * 0.20;
      canvas.drawLine(
        base,
        base.translate(0, -h),
        Paint()
          ..color = const Color(0xFF6B5030).withOpacity(fade)
          ..strokeWidth = math.max(2, h * 0.09)
          ..strokeCap = StrokeCap.round,
      );
      for (int i = 0; i < 5; i++) {
        final double a = -math.pi / 2 + (i - 2) * 0.5;
        final double sway = math.sin(progress * math.pi * 2 + i) * 0.05;
        canvas.drawLine(
          base.translate(0, -h),
          base.translate(
              math.cos(a + sway) * h * 0.5, -h + math.sin(a + sway) * h * 0.5),
          Paint()
            ..color = MosesColors.reed.withOpacity(fade)
            ..strokeWidth = math.max(1.5, h * 0.08)
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintGuards(Canvas canvas, Size size, double horizon) {
    // Two guards on the steps. Boils makes them flinch — they step back and
    // raise a hand, which is as far as this level ever goes.
    final double flinch = effect == PlagueEffect.boils ? _pulse : 0;
    for (final double side in <double>[-1, 1]) {
      final Offset feet = Offset(
        size.width * (0.5 + side * (0.20 + flinch * 0.03)),
        horizon + size.height * 0.055,
      );
      final double h = size.height * 0.13;
      canvas.drawOval(
        Rect.fromCenter(center: feet, width: h * 0.4, height: h * 0.07),
        Paint()..color = Colors.black.withOpacity(0.16),
      );
      final Path robe = Path()
        ..moveTo(feet.dx - h * 0.14, feet.dy - h * 0.72)
        ..lineTo(feet.dx + h * 0.14, feet.dy - h * 0.72)
        ..lineTo(feet.dx + h * 0.2, feet.dy)
        ..lineTo(feet.dx - h * 0.2, feet.dy)
        ..close();
      canvas.drawPath(robe, Paint()..color = const Color(0xFF9A8156));
      canvas.drawCircle(
        Offset(feet.dx, feet.dy - h * 0.85),
        h * 0.14,
        Paint()..color = const Color(0xFFE8C39A),
      );
      // Spear, or a raised hand when flinching.
      canvas.drawLine(
        Offset(feet.dx + side * h * 0.22, feet.dy),
        Offset(feet.dx + side * h * 0.22, feet.dy - h * (1.0 + flinch * 0.15)),
        Paint()
          ..color = const Color(0xFF6B5030)
          ..strokeWidth = math.max(1.5, h * 0.05),
      );
    }
  }

  void _paintCattle(Canvas canvas, Size size, double horizon) {
    // One grazing animal, calm. The livestock plague wobbles it and drifts it
    // to the side — it is never shown harmed, only unwell and then gone.
    final bool gone = placed.contains(PlagueEffect.livestock) &&
        effect != PlagueEffect.livestock;
    if (gone) return;

    final double wobble =
        effect == PlagueEffect.livestock ? math.sin(t * math.pi * 8) * 0.06 : 0;
    final double drift =
        effect == PlagueEffect.livestock ? _pulse * size.width * 0.10 : 0;
    final double fade =
        effect == PlagueEffect.livestock ? (1 - t).clamp(0.0, 1.0) : 1.0;

    final Offset base =
        Offset(size.width * 0.22 - drift, horizon + size.height * 0.115);
    final double h = size.height * 0.075;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(wobble);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, -h * 0.55), width: h * 1.5, height: h * 0.72),
        Radius.circular(h * 0.3),
      ),
      Paint()..color = const Color(0xFFCBB79A).withOpacity(fade),
    );
    canvas.drawCircle(Offset(-h * 0.78, -h * 0.75), h * 0.3,
        Paint()..color = const Color(0xFFCBB79A).withOpacity(fade));
    for (final double lx in <double>[-0.5, 0.0, 0.5]) {
      canvas.drawLine(
        Offset(h * lx, -h * 0.2),
        Offset(h * lx, 0),
        Paint()
          ..color = const Color(0xFF9C8161).withOpacity(fade)
          ..strokeWidth = math.max(1.5, h * 0.12),
      );
    }
    canvas.restore();
  }

  void _paintRiver(Canvas canvas, Size size, double horizon) {
    final Rect river =
        Rect.fromLTWH(0, size.height * 0.88, size.width, size.height * 0.12);
    // Blood is one of the two effects that persists — the river stays red for
    // the rest of the level once it has turned.
    final bool bloodied = placed.contains(PlagueEffect.bloodRiver);
    final double turning = effect == PlagueEffect.bloodRiver ? t : 0;
    final Color water = bloodied
        ? const Color(0xFF8E2B2B)
        : Color.lerp(MosesColors.water, const Color(0xFF8E2B2B), turning)!;

    canvas.drawRect(river, Paint()..color = water);
    for (int i = 0; i < 5; i++) {
      final double y = river.top + river.height * (0.2 + i * 0.18);
      final double shift =
          math.sin(progress * math.pi * 2 + i) * size.width * 0.03;
      canvas.drawLine(
        Offset(-size.width * 0.1 + shift, y),
        Offset(size.width * 1.1 + shift, y),
        Paint()
          ..color = Colors.white.withOpacity(bloodied ? 0.10 : 0.16)
          ..strokeWidth = 2,
      );
    }
  }

  void _paintCrown(Canvas canvas, Size size, double horizon) {
    // On the palace roof from the first round, so the child has been looking
    // at it for the whole level before it finally comes off.
    final double roofY = horizon - size.height * 0.40;
    final double w = size.width * 0.075;
    double cx = size.width * 0.5;
    double cy = roofY - size.height * 0.03;
    double tilt = 0;
    double alpha = 1;

    if (effect == PlagueEffect.crownFall) {
      // Tips, then falls off the roof and out of the scene.
      tilt = t * 1.6;
      cx += t * t * size.width * 0.14;
      cy += t * t * size.height * 0.55;
      alpha = (1 - t * 0.5).clamp(0.0, 1.0);
    } else if (crownFallen) {
      return;
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);
    final Path crown = Path()
      ..moveTo(-w / 2, w * 0.28)
      ..lineTo(-w / 2, -w * 0.18)
      ..lineTo(-w * 0.22, w * 0.06)
      ..lineTo(0, -w * 0.30)
      ..lineTo(w * 0.22, w * 0.06)
      ..lineTo(w / 2, -w * 0.18)
      ..lineTo(w / 2, w * 0.28)
      ..close();
    canvas.drawPath(
        crown, Paint()..color = MosesColors.robeTrim.withOpacity(alpha));
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFFB8860B).withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------- effects

  void _paintEffect(Canvas canvas, Size size, double horizon) {
    switch (effect!) {
      // Blood, locusts, livestock, boils, darkness and the crown are all
      // drawn by the world itself above, because they change what Egypt *is*
      // rather than adding something on top of it.
      case PlagueEffect.bloodRiver:
      case PlagueEffect.livestock:
      case PlagueEffect.boils:
      case PlagueEffect.darkness:
      case PlagueEffect.crownFall:
        break;
      case PlagueEffect.frogs:
        _paintFrogs(canvas, size, horizon);
      case PlagueEffect.gnats:
        _paintGnats(canvas, size, horizon);
      case PlagueEffect.flies:
        _paintFlies(canvas, size, horizon);
      case PlagueEffect.hail:
        _paintHail(canvas, size, horizon);
      case PlagueEffect.locusts:
        _paintLocusts(canvas, size, horizon);
    }
  }

  void _paintFrogs(Canvas canvas, Size size, double horizon) {
    for (int i = 0; i < 9; i++) {
      final double phase = (t * 2.4 + i * 0.17) % 1;
      final double x = size.width * (0.08 + (i / 8) * 0.84);
      // Each hop is an arc, so they bound across rather than slide.
      final double hop = math.sin(phase * math.pi * 3).abs();
      final double y = horizon + size.height * 0.10 - hop * size.height * 0.05;
      final double r = size.width * 0.016;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 2.2, height: r * 1.6),
        Paint()..color = const Color(0xFF5C8A3A).withOpacity(_pulse),
      );
      for (final double side in <double>[-1, 1]) {
        canvas.drawCircle(
          Offset(x + side * r * 0.5, y - r * 0.7),
          r * 0.35,
          Paint()..color = const Color(0xFF3E6327).withOpacity(_pulse),
        );
      }
    }
  }

  void _paintGnats(Canvas canvas, Size size, double horizon) {
    // A speckled haze over the palace, not individual insects.
    final Rect haze = Rect.fromLTWH(size.width * 0.2,
        horizon - size.height * 0.42, size.width * 0.6, size.height * 0.44);
    canvas.drawRect(
      haze,
      Paint()..color = const Color(0xFF6E6247).withOpacity(0.22 * _pulse),
    );
    for (int i = 0; i < 70; i++) {
      final double x = haze.left + ((i * 61) % 100) / 100 * haze.width;
      final double y = haze.top + ((i * 37) % 100) / 100 * haze.height;
      final double j = math.sin(progress * math.pi * 6 + i) * 2;
      canvas.drawCircle(
        Offset(x + j, y - j),
        1.1,
        Paint()..color = const Color(0xFF3F3A2C).withOpacity(0.55 * _pulse),
      );
    }
  }

  void _paintFlies(Canvas canvas, Size size, double horizon) {
    // Swarming at the windows specifically, so it reads as flies finding a
    // way in rather than generic specks.
    for (final Offset w in _windowSpots(size, horizon)) {
      for (int i = 0; i < 14; i++) {
        final double a = i * 0.9 + progress * math.pi * 4;
        final double r = size.width * (0.02 + (i % 4) * 0.012);
        canvas.drawCircle(
          w.translate(math.cos(a) * r, math.sin(a * 1.3) * r * 0.8),
          1.6,
          Paint()..color = const Color(0xFF1E1B14).withOpacity(0.8 * _pulse),
        );
      }
    }
  }

  void _paintHail(Canvas canvas, Size size, double horizon) {
    // Ice and fire together, as the text has it.
    for (int i = 0; i < 34; i++) {
      final double x = ((i * 53) % 100) / 100 * size.width;
      final double fall = ((t * 1.6) + (i % 7) * 0.14) % 1;
      final double y = fall * horizon;
      final bool fire = i % 3 == 0;
      if (fire) {
        canvas.drawCircle(
          Offset(x, y),
          size.width * 0.008,
          Paint()..color = const Color(0xFFFF8A3D).withOpacity(_pulse),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(x, y),
                width: size.width * 0.012,
                height: size.width * 0.016),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFDCF0FF).withOpacity(_pulse),
        );
      }
    }
  }

  void _paintLocusts(Canvas canvas, Size size, double horizon) {
    // A swarm sweeping left to right across the whole frame.
    final double sweep = t;
    for (int i = 0; i < 60; i++) {
      final double lane = ((i * 29) % 100) / 100;
      final double x =
          (sweep * 1.5 - lane * 0.4) * size.width * 1.2 - size.width * 0.15;
      final double y = horizon * (0.18 + lane * 0.82) +
          math.sin(progress * math.pi * 6 + i) * size.height * 0.012;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y),
            width: size.width * 0.02,
            height: size.width * 0.009),
        Paint()..color = const Color(0xFF6B6234).withOpacity(0.9 * _pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EgyptPainter old) =>
      old.progress != progress ||
      old.t != t ||
      old.effect != effect ||
      old.crownFallen != crownFallen ||
      old.placed.length != placed.length;
}
