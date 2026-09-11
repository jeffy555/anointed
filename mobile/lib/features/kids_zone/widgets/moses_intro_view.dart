import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/moses_exodus_level.dart';

/// Animated backdrop for the Moses introduction — Egypt, the Nile, and dawn.
///
/// Driven entirely by [MosesEra], the way `ArkSceneView` is driven by weather,
/// so one widget carries the whole arc from a hard Egyptian noon to the golden
/// morning the basket is found in. The story's turn is a turn in the sky.
class MosesIntroView extends StatefulWidget {
  const MosesIntroView({
    super.key,
    required this.era,
    this.figures = const <MosesFigure>[],
  });

  final MosesEra era;
  final List<MosesFigure> figures;

  @override
  State<MosesIntroView> createState() => _MosesIntroViewState();
}

class _MosesIntroViewState extends State<MosesIntroView>
    with TickerProviderStateMixin {
  late final AnimationController _loop;

  /// Runs once per beat so the cast rises into frame instead of appearing
  /// fully formed the instant the narration starts.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void didUpdateWidget(MosesIntroView old) {
    super.didUpdateWidget(old);
    if (old.era != widget.era || old.figures != widget.figures) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // The sky cross-fades between beats rather than cutting, so the
              // story darkens and lifts instead of flicking between slides.
              AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(gradient: mosesSkyFor(widget.era)),
              ),
              // The cast is painted by the same painter that paints the
              // world, so the figures stand *in* the scene — sharing its light,
              // its ground line and its scale — rather than floating over it as
              // separate widgets pasted on top.
              AnimatedBuilder(
                animation: _loop,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _MosesIntroPainter(
                      era: widget.era,
                      progress: _loop.value,
                      figures: widget.figures,
                      entrance: _entrance.value,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Exposed for tests: every beat has to actually change the sky, or the
/// backdrop is doing none of the storytelling it claims to.
LinearGradient mosesSkyFor(MosesEra era) {
  return switch (era) {
    // A hard, bleached noon — Egypt at work, no shade anywhere.
    MosesEra.egypt => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF7FB2CC),
          Color(0xFFE4D3AE),
          Color(0xFFE2C48A)
        ],
      ),
    // The decree drains the colour out of it.
    MosesEra.decree => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF6B6F78),
          Color(0xFF9A9384),
          Color(0xFFBFAE8E)
        ],
      ),
    // Indoors: dark outside, one warm lamp inside.
    MosesEra.hiding => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF2A2E3D),
          Color(0xFF4A4234),
          Color(0xFF7A5C33)
        ],
      ),
    MosesEra.basket => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF3A4256),
          Color(0xFF6B6248),
          Color(0xFFA98352)
        ],
      ),
    // Night on the Nile.
    MosesEra.river => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF16233B),
          Color(0xFF27466B),
          Color(0xFF2E6E74)
        ],
      ),
    // Dawn at the palace steps.
    MosesEra.discovery => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF5B7FA8),
          Color(0xFFD9A98C),
          Color(0xFFF3D9A8)
        ],
      ),
    // Full morning gold — the promise kept.
    MosesEra.promise => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF8ECAE6),
          Color(0xFFFFD98A),
          Color(0xFFFFE8C2)
        ],
      ),
  };
}

class _MosesIntroPainter extends CustomPainter {
  _MosesIntroPainter({
    required this.era,
    required this.progress,
    required this.figures,
    required this.entrance,
  });

  final MosesEra era;

  /// 0..1, looping.
  final double progress;

  final List<MosesFigure> figures;

  /// 0..1, once per beat, as the cast rises into frame.
  final double entrance;

  bool get _isNight =>
      era == MosesEra.hiding || era == MosesEra.basket || era == MosesEra.river;

  bool get _onWater =>
      era == MosesEra.river ||
      era == MosesEra.discovery ||
      era == MosesEra.promise;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final double horizon = size.height * 0.58;

    if (_isNight) _paintStars(canvas, size);
    if (era == MosesEra.promise || era == MosesEra.discovery) {
      _paintSun(canvas, size, horizon);
    }
    _paintPyramids(canvas, size, horizon);
    _paintPalms(canvas, size, horizon);

    if (_onWater) {
      _paintNile(canvas, size, horizon);
      _paintReeds(canvas, size, horizon);
    } else {
      _paintSand(canvas, size, horizon);
    }

    if (era == MosesEra.egypt || era == MosesEra.decree) {
      _paintBrickPits(canvas, size, horizon);
    }
    if (era == MosesEra.hiding || era == MosesEra.basket) {
      _paintLamp(canvas, size, horizon);
    }
    if (era == MosesEra.promise) _paintRays(canvas, size);

    // Painted last so the cast stands in front of the reeds and the water.
    for (final MosesFigure f in figures) {
      _paintFigure(canvas, size, f);
    }
  }

  // ------------------------------------------------------------------- cast

  /// Skin, robes and hair, dimmed on the night beats so the cast sits in the
  /// scene's own light rather than looking cut out and pasted on.
  Color _lit(Color base) {
    if (!_isNight) return base;
    return Color.lerp(base, const Color(0xFF16233B), 0.34)!;
  }

  void _paintFigure(Canvas canvas, Size size, MosesFigure f) {
    final Offset base = Offset(size.width * f.left, size.height * f.baseline);
    // One figure height for the whole scene, so a mother and a princess in the
    // same beat are the same species of person rather than two unrelated
    // drawings that happen to share a canvas.
    final double h = size.height * 0.30 * f.scale;

    // Rise into place: a short lift plus a fade, eased.
    final double t = Curves.easeOutCubic.transform(entrance.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(0, (1 - t) * h * 0.18);

    switch (f.kind) {
      case MosesFigureKind.family:
        _paintPerson(canvas, base.translate(-h * 0.30, 0), h * 0.98,
            robe: const Color(0xFF7E9AAE),
            hair: const Color(0xFF3A2A1C),
            alpha: t);
        _paintPerson(canvas, base, h,
            robe: const Color(0xFFB98A5E),
            hair: const Color(0xFF2C1E14),
            beard: true,
            alpha: t);
        _paintPerson(canvas, base.translate(h * 0.28, 0), h * 0.66,
            robe: const Color(0xFFD8C08F),
            hair: const Color(0xFF3A2A1C),
            alpha: t);
      case MosesFigureKind.worker:
        _paintWorker(canvas, base, h, t);
      case MosesFigureKind.palaceDecree:
        _paintPalaceDecree(canvas, base, h, t);
      case MosesFigureKind.motherHolding:
        _paintPerson(canvas, base, h,
            robe: const Color(0xFF9C6B8E),
            hair: const Color(0xFF2C1E14),
            headscarf: true,
            cradling: true,
            alpha: t);
      case MosesFigureKind.motherWeaving:
        _paintMotherWeaving(canvas, base, h, t);
      case MosesFigureKind.basketOnWater:
        _paintBasketWithBaby(canvas, base, h * 0.42, t, afloat: true);
      case MosesFigureKind.girlWatching:
        _paintGirlWatching(canvas, base, h * 0.78, t);
      case MosesFigureKind.princessReaching:
        _paintPerson(canvas, base, h,
            robe: MosesColors.robe,
            hair: const Color(0xFF241812),
            crown: true,
            reaching: true,
            alpha: t);
      case MosesFigureKind.princessHolding:
        _paintPerson(canvas, base, h,
            robe: MosesColors.robe,
            hair: const Color(0xFF241812),
            crown: true,
            cradling: true,
            alpha: t);
    }
    canvas.restore();
  }

  /// The one human the whole cast is built from.
  ///
  /// Everybody gets a head with an actual face, a robe that falls to the
  /// ground, arms and feet — so a figure reads as a person at a glance, which
  /// a glyph never did. The variations (beard, headscarf, crown, a cradled
  /// baby, a reaching arm) are what tell one character from another.
  void _paintPerson(
    Canvas canvas,
    Offset feet,
    double height, {
    required Color robe,
    required Color hair,
    double alpha = 1,
    bool beard = false,
    bool headscarf = false,
    bool crown = false,
    bool cradling = false,
    bool reaching = false,
    bool kneeling = false,
  }) {
    if (height < 4) return;
    final double headR = height * 0.115;
    final double bodyTop = feet.dy - height + headR * 2.1;
    final Offset head = Offset(feet.dx, feet.dy - height + headR);
    final Color skin = _lit(const Color(0xFFE8C39A)).withOpacity(alpha);
    final Color cloth = _lit(robe).withOpacity(alpha);

    // A soft contact shadow, so the figure is standing on the ground rather
    // than hovering a little above it.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(feet.dx, feet.dy),
          width: height * 0.34,
          height: height * 0.05),
      Paint()..color = Colors.black.withOpacity(0.18 * alpha),
    );

    // Robe: a trapezoid falling from the shoulders to the floor.
    final double shoulder = height * 0.15;
    final double hem = height * (kneeling ? 0.20 : 0.23);
    final Path gown = Path()
      ..moveTo(feet.dx - shoulder, bodyTop)
      ..lineTo(feet.dx + shoulder, bodyTop)
      ..lineTo(feet.dx + hem, feet.dy)
      ..lineTo(feet.dx - hem, feet.dy)
      ..close();
    canvas.drawPath(gown, Paint()..color = cloth);
    // A belt, and a fold line, so the robe has a body under it.
    canvas.drawRect(
      Rect.fromLTWH(feet.dx - shoulder * 0.92, bodyTop + height * 0.20,
          shoulder * 1.84, height * 0.035),
      Paint()..color = _lit(MosesColors.robeTrim).withOpacity(0.85 * alpha),
    );
    canvas.drawLine(
      Offset(feet.dx, bodyTop + height * 0.26),
      Offset(feet.dx, feet.dy - height * 0.02),
      Paint()
        ..color = Colors.black.withOpacity(0.10 * alpha)
        ..strokeWidth = math.max(1, height * 0.012),
    );

    // Arms.
    final Paint arm = Paint()
      ..color = skin
      ..strokeWidth = math.max(1.5, height * 0.045)
      ..strokeCap = StrokeCap.round;
    final Offset shoulderL =
        Offset(feet.dx - shoulder * 0.85, bodyTop + height * 0.06);
    final Offset shoulderR =
        Offset(feet.dx + shoulder * 0.85, bodyTop + height * 0.06);
    if (cradling) {
      // Both arms come together in front — the shape that says "holding".
      canvas.drawLine(shoulderL,
          Offset(feet.dx - height * 0.05, bodyTop + height * 0.24), arm);
      canvas.drawLine(shoulderR,
          Offset(feet.dx + height * 0.10, bodyTop + height * 0.24), arm);
    } else if (reaching) {
      canvas.drawLine(shoulderL,
          Offset(feet.dx - height * 0.30, bodyTop + height * 0.34), arm);
      canvas.drawLine(shoulderR,
          Offset(feet.dx + height * 0.14, bodyTop + height * 0.30), arm);
    } else {
      canvas.drawLine(shoulderL,
          Offset(feet.dx - shoulder * 1.0, bodyTop + height * 0.30), arm);
      canvas.drawLine(shoulderR,
          Offset(feet.dx + shoulder * 1.0, bodyTop + height * 0.30), arm);
    }

    // Head, hair and face.
    canvas.drawCircle(head, headR, Paint()..color = skin);
    if (headscarf) {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: headR * 1.14),
        math.pi * 0.86,
        math.pi * 1.28,
        true,
        Paint()..color = _lit(const Color(0xFF6E5A7A)).withOpacity(alpha),
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: headR * 1.05),
        math.pi,
        math.pi,
        true,
        Paint()..color = _lit(hair).withOpacity(alpha),
      );
      // A little length at the sides, so the head is not a bald ball.
      for (final double side in <double>[-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center:
                Offset(head.dx + side * headR * 0.92, head.dy + headR * 0.2),
            width: headR * 0.5,
            height: headR * 1.2,
          ),
          Paint()..color = _lit(hair).withOpacity(alpha),
        );
      }
    }
    if (crown) {
      final Path band = Path()
        ..moveTo(head.dx - headR * 1.0, head.dy - headR * 0.55)
        ..lineTo(head.dx - headR * 0.55, head.dy - headR * 1.25)
        ..lineTo(head.dx, head.dy - headR * 0.7)
        ..lineTo(head.dx + headR * 0.55, head.dy - headR * 1.25)
        ..lineTo(head.dx + headR * 1.0, head.dy - headR * 0.55)
        ..close();
      canvas.drawPath(
          band, Paint()..color = _lit(MosesColors.robeTrim).withOpacity(alpha));
    }
    _paintFace(canvas, head, headR, alpha);
    if (beard) {
      canvas.drawArc(
        Rect.fromCircle(
            center: head.translate(0, headR * 0.32), radius: headR * 0.85),
        0.15,
        math.pi - 0.3,
        true,
        Paint()..color = _lit(hair).withOpacity(0.92 * alpha),
      );
    }

    if (cradling) {
      _paintSwaddledBaby(
          canvas,
          Offset(feet.dx + height * 0.02, bodyTop + height * 0.235),
          height * 0.13,
          alpha);
    }
  }

  /// Two eyes and a mouth. Small, but it is the whole difference between a
  /// person and a silhouette.
  void _paintFace(Canvas canvas, Offset head, double r, double alpha) {
    final Paint ink = Paint()
      ..color = _lit(MosesColors.ink).withOpacity(0.85 * alpha);
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
          Offset(head.dx + side * r * 0.34, head.dy + r * 0.05), r * 0.11, ink);
    }
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(head.dx, head.dy + r * 0.36),
          width: r * 0.6,
          height: r * 0.4),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = _lit(MosesColors.ink).withOpacity(0.7 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.11),
    );
    // A hint of cheek, so faces are warm rather than blank.
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(head.dx + side * r * 0.6, head.dy + r * 0.3),
        r * 0.15,
        Paint()..color = const Color(0xFFE79A86).withOpacity(0.35 * alpha),
      );
    }
  }

  /// A baby, wrapped — round face, closed eyes, a tuft of hair, and swaddling
  /// cloth. Never drawn on its own: it is always in arms or in the basket.
  void _paintSwaddledBaby(
      Canvas canvas, Offset centre, double r, double alpha) {
    if (r < 2) return;
    // Swaddle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: centre.translate(0, r * 0.35),
            width: r * 1.9,
            height: r * 1.3),
        Radius.circular(r * 0.6),
      ),
      Paint()..color = _lit(MosesColors.cloth).withOpacity(alpha),
    );
    canvas.drawLine(
      Offset(centre.dx - r * 0.8, centre.dy + r * 0.5),
      Offset(centre.dx + r * 0.8, centre.dy + r * 0.35),
      Paint()
        ..color = _lit(const Color(0xFFE0CBA8)).withOpacity(alpha)
        ..strokeWidth = math.max(1, r * 0.16),
    );
    // Head.
    final Offset head = centre.translate(0, -r * 0.45);
    canvas.drawCircle(head, r * 0.72,
        Paint()..color = _lit(const Color(0xFFF0CBA6)).withOpacity(alpha));
    // A tuft of hair.
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: r * 0.72),
      math.pi * 1.15,
      math.pi * 0.7,
      true,
      Paint()..color = _lit(const Color(0xFF3A2A1C)).withOpacity(alpha),
    );
    // Asleep: two closed-eye lashes and a small mouth.
    final Paint ink = Paint()
      ..color = _lit(MosesColors.ink).withOpacity(0.8 * alpha)
      ..strokeWidth = math.max(1, r * 0.12)
      ..strokeCap = StrokeCap.round;
    for (final double side in <double>[-1, 1]) {
      canvas.drawLine(
        Offset(head.dx + side * r * 0.3 - r * 0.13, head.dy + r * 0.06),
        Offset(head.dx + side * r * 0.3 + r * 0.13, head.dy + r * 0.06),
        ink,
      );
    }
    canvas.drawCircle(
      Offset(head.dx, head.dy + r * 0.36),
      r * 0.1,
      Paint()..color = _lit(MosesColors.ink).withOpacity(0.6 * alpha),
    );
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(head.dx + side * r * 0.5, head.dy + r * 0.24),
        r * 0.14,
        Paint()..color = const Color(0xFFE79A86).withOpacity(0.45 * alpha),
      );
    }
  }

  /// The basket, with the baby inside it — the fix for a basket that used to
  /// float on its own with nothing in it.
  void _paintBasketWithBaby(
      Canvas canvas, Offset waterline, double r, double alpha,
      {bool afloat = false}) {
    final double bob = afloat ? math.sin(progress * math.pi * 2) * r * 0.06 : 0;
    final Offset c = waterline.translate(0, bob);

    if (afloat) {
      // Ripples where it sits in the water, so it is *on* the river.
      for (int i = 0; i < 2; i++) {
        final double w = r * (2.2 + i * 0.9);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: w, height: r * 0.3),
          Paint()
            ..color = MosesColors.foam.withOpacity((0.30 - i * 0.12) * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, r * 0.06),
        );
      }
    }

    // The baby sits inside, so it is drawn before the basket's front wall and
    // clipped by it — the head and shoulders show above the rim.
    _paintSwaddledBaby(canvas, c.translate(0, -r * 0.62), r * 0.5, alpha);

    // Basket body: a woven half-oval, front wall over the baby's swaddle.
    final Rect body = Rect.fromCenter(
      center: c.translate(0, -r * 0.12),
      width: r * 1.9,
      height: r * 0.95,
    );
    final Path hull = Path()
      ..moveTo(body.left, body.top)
      ..quadraticBezierTo(
          body.center.dx, body.bottom + r * 0.28, body.right, body.top)
      ..close();
    canvas.drawPath(
        hull, Paint()..color = _lit(MosesColors.basket).withOpacity(alpha));
    // Weave.
    for (int i = 1; i < 5; i++) {
      final double x = body.left + body.width * i / 5;
      canvas.drawLine(
        Offset(x, body.top + r * 0.06),
        Offset(x, body.bottom - r * 0.04),
        Paint()
          ..color = _lit(MosesColors.basketDark).withOpacity(0.45 * alpha)
          ..strokeWidth = math.max(1, r * 0.06),
      );
    }
    canvas.drawLine(
      Offset(body.left + r * 0.1, body.center.dy),
      Offset(body.right - r * 0.1, body.center.dy),
      Paint()
        ..color = _lit(MosesColors.basketDark).withOpacity(0.4 * alpha)
        ..strokeWidth = math.max(1, r * 0.06),
    );
    // Rim.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(body.center.dx, body.top),
            width: body.width * 1.06,
            height: r * 0.26),
        Radius.circular(r * 0.13),
      ),
      Paint()..color = _lit(MosesColors.basketLight).withOpacity(alpha),
    );
  }

  void _paintWorker(Canvas canvas, Offset feet, double h, double alpha) {
    _paintPerson(canvas, feet, h,
        robe: const Color(0xFFA9805A),
        hair: const Color(0xFF2C1E14),
        alpha: alpha);
    // A load of mud bricks carried on the shoulder.
    final double headR = h * 0.115;
    final double shoulderY = feet.dy - h + headR * 2.1 + h * 0.05;
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(feet.dx + h * 0.10,
              shoulderY - h * 0.10 + i * h * 0.045, h * 0.20, h * 0.04),
          Radius.circular(h * 0.008),
        ),
        Paint()..color = _lit(const Color(0xFF9C6B43)).withOpacity(alpha),
      );
    }
  }

  void _paintPalaceDecree(Canvas canvas, Offset feet, double h, double alpha) {
    // An empty throne and a hanging decree. The command is shown as a document
    // and a seat of power, never as a child being taken — the story says what
    // happened; the picture does not have to show it.
    final double w = h * 0.46;
    final Rect seat =
        Rect.fromLTWH(feet.dx - w / 2, feet.dy - h * 0.42, w, h * 0.42);
    canvas.drawRect(seat,
        Paint()..color = _lit(const Color(0xFF8C7355)).withOpacity(alpha));
    canvas.drawRect(
      Rect.fromLTWH(
          seat.left - w * 0.08, seat.top - h * 0.34, w * 0.22, h * 0.76),
      Paint()..color = _lit(const Color(0xFF6F5A42)).withOpacity(alpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(
          seat.right - w * 0.14, seat.top - h * 0.34, w * 0.22, h * 0.76),
      Paint()..color = _lit(const Color(0xFF6F5A42)).withOpacity(alpha),
    );
    // Gilding, so it reads as a throne rather than a crate.
    canvas.drawRect(
      Rect.fromLTWH(seat.left, seat.top, w, h * 0.045),
      Paint()..color = _lit(MosesColors.robeTrim).withOpacity(0.9 * alpha),
    );

    // The decree: a scroll, unrolled, swaying very slightly.
    final double sway = math.sin(progress * math.pi * 2) * h * 0.012;
    final Rect scroll = Rect.fromLTWH(
        feet.dx - w * 0.28 + sway, feet.dy - h * 0.98, w * 0.56, h * 0.40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scroll, Radius.circular(h * 0.02)),
      Paint()..color = _lit(const Color(0xFFF0E2C2)).withOpacity(alpha),
    );
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(scroll.left + w * 0.08, scroll.top + h * 0.07 + i * h * 0.075),
        Offset(scroll.right - w * 0.08, scroll.top + h * 0.07 + i * h * 0.075),
        Paint()
          ..color = _lit(const Color(0xFF7A6A50)).withOpacity(0.75 * alpha)
          ..strokeWidth = math.max(1, h * 0.012),
      );
    }
    canvas.drawCircle(
      Offset(scroll.center.dx, scroll.bottom - h * 0.02),
      h * 0.028,
      Paint()..color = _lit(MosesColors.heart).withOpacity(0.9 * alpha),
    );
  }

  void _paintMotherWeaving(Canvas canvas, Offset feet, double h, double alpha) {
    // Kneeling, leaning toward the basket she is working on.
    _paintPerson(canvas, feet, h * 0.82,
        robe: const Color(0xFF9C6B8E),
        hair: const Color(0xFF2C1E14),
        headscarf: true,
        reaching: true,
        kneeling: true,
        alpha: alpha);
    _paintBasketWithBaby(
        canvas, feet.translate(-h * 0.34, -h * 0.02), h * 0.20, alpha);
  }

  void _paintGirlWatching(Canvas canvas, Offset feet, double h, double alpha) {
    _paintPerson(canvas, feet, h,
        robe: const Color(0xFF7FA88C),
        hair: const Color(0xFF241812),
        alpha: alpha);
    // A hand raised to shade her eyes — the pose that says "watching".
    final double headR = h * 0.115;
    final Offset head = Offset(feet.dx, feet.dy - h + headR);
    canvas.drawLine(
      Offset(feet.dx + h * 0.13, feet.dy - h + headR * 2.6),
      Offset(head.dx + headR * 0.4, head.dy - headR * 0.5),
      Paint()
        ..color = _lit(const Color(0xFFE8C39A)).withOpacity(alpha)
        ..strokeWidth = math.max(1.5, h * 0.045)
        ..strokeCap = StrokeCap.round,
    );
    // A few reeds in front of her, so she is hidden behind them.
    for (int i = -2; i <= 2; i++) {
      final double x = feet.dx + i * h * 0.10;
      canvas.drawLine(
        Offset(x, feet.dy + h * 0.04),
        Offset(x + i * h * 0.012, feet.dy - h * 0.62),
        Paint()
          ..color = _lit(MosesColors.reedDark).withOpacity(0.85 * alpha)
          ..strokeWidth = math.max(1.5, h * 0.028)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    for (int i = 0; i < 40; i++) {
      // Deterministic scatter — a fixed sky that twinkles, not a new sky
      // every frame.
      final double x = ((i * 73) % 100) / 100 * size.width;
      final double y = ((i * 137) % 55) / 100 * size.height;
      final double twinkle =
          0.35 + 0.35 * math.sin(progress * math.pi * 2 + i * 0.7);
      canvas.drawCircle(
        Offset(x, y),
        (i % 3 == 0 ? 1.6 : 1.0),
        Paint()..color = Colors.white.withOpacity(twinkle),
      );
    }
    // A low moon over the river.
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.18),
      size.width * 0.055,
      Paint()..color = const Color(0xFFF6EEDA).withOpacity(0.92),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.18),
      size.width * 0.11,
      Paint()
        ..color = const Color(0xFFF6EEDA).withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  void _paintSun(Canvas canvas, Size size, double horizon) {
    final double rise = era == MosesEra.promise ? 0.30 : 0.44;
    final Offset sun = Offset(size.width * 0.72, size.height * rise);
    canvas.drawCircle(
      sun,
      size.width * 0.085,
      Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.95),
    );
    canvas.drawCircle(
      sun,
      size.width * 0.2,
      Paint()
        ..color = const Color(0xFFFFD98A).withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  void _paintPyramids(Canvas canvas, Size size, double horizon) {
    // Silhouettes only, and further back in the night beats — the pyramids
    // say "Egypt" faster than any other single shape.
    final double opacity = _isNight ? 0.42 : 0.30;
    final Color stone =
        _isNight ? const Color(0xFF1B2436) : const Color(0xFFB79B72);

    void pyramid(double cx, double halfWidth, double height) {
      final Path p = Path()
        ..moveTo(cx, horizon - height)
        ..lineTo(cx + halfWidth, horizon)
        ..lineTo(cx - halfWidth, horizon)
        ..close();
      canvas.drawPath(p, Paint()..color = stone.withOpacity(opacity));
      // Sunlit face, so it reads as a solid rather than a flat triangle.
      final Path lit = Path()
        ..moveTo(cx, horizon - height)
        ..lineTo(cx + halfWidth, horizon)
        ..lineTo(cx, horizon)
        ..close();
      canvas.drawPath(lit, Paint()..color = Colors.white.withOpacity(0.06));
    }

    pyramid(size.width * 0.18, size.width * 0.16, size.height * 0.20);
    pyramid(size.width * 0.36, size.width * 0.11, size.height * 0.14);
  }

  void _paintPalms(Canvas canvas, Size size, double horizon) {
    final Color trunk =
        _isNight ? const Color(0xFF16202E) : const Color(0xFF4E8A3C);
    final double opacity = _isNight ? 0.75 : 0.85;

    void palm(double x, double height) {
      canvas.drawLine(
        Offset(x, horizon),
        Offset(x - height * 0.08, horizon - height),
        Paint()
          ..color = trunk.withOpacity(opacity)
          ..strokeWidth = math.max(2, height * 0.06)
          ..strokeCap = StrokeCap.round,
      );
      for (int i = 0; i < 5; i++) {
        final double a = -math.pi / 2 + (i - 2) * 0.55;
        // A slow sway, the only motion in the still beats.
        final double sway = math.sin(progress * math.pi * 2 + i) * 0.05;
        final Offset top = Offset(x - height * 0.08, horizon - height);
        final Path frond = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            top.dx + math.cos(a + sway) * height * 0.30,
            top.dy + math.sin(a + sway) * height * 0.30,
            top.dx + math.cos(a + sway) * height * 0.5,
            top.dy + math.sin(a + sway) * height * 0.5 + height * 0.1,
          );
        canvas.drawPath(
          frond,
          Paint()
            ..color = trunk.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, height * 0.07)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    palm(size.width * 0.86, size.height * 0.20);
    palm(size.width * 0.94, size.height * 0.15);
  }

  void _paintSand(Canvas canvas, Size size, double horizon) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()
        ..color = _isNight ? const Color(0xFF3B3323) : const Color(0xFFE2C48A),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height * 0.03),
      Paint()..color = Colors.black.withOpacity(0.08),
    );
  }

  void _paintNile(Canvas canvas, Size size, double horizon) {
    final Rect water =
        Rect.fromLTWH(0, horizon, size.width, size.height - horizon);
    canvas.drawRect(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _isNight
              ? const <Color>[Color(0xFF1B4A56), Color(0xFF0E2B38)]
              : const <Color>[MosesColors.waterLight, MosesColors.waterDeep],
        ).createShader(water),
    );

    // Ripple lines drifting toward the viewer.
    for (int i = 0; i < 7; i++) {
      final double t = ((progress + i / 7) % 1);
      final double y = horizon + (size.height - horizon) * t * t;
      canvas.drawLine(
        Offset(size.width * (0.5 - 0.5 * t), y),
        Offset(size.width * (0.5 + 0.5 * t), y),
        Paint()
          ..color = MosesColors.foam.withOpacity(0.10 + 0.12 * t)
          ..strokeWidth = 1 + 2 * t,
      );
    }

    // A path of light on the water — moonlight at night, sunrise at dawn.
    final Color glint =
        _isNight ? const Color(0xFFF6EEDA) : const Color(0xFFFFE8C2);
    for (int i = 0; i < 6; i++) {
      final double t = i / 6;
      final double y = horizon + (size.height - horizon) * (0.1 + t * 0.85);
      final double w = size.width *
          (0.03 + t * 0.09) *
          (0.7 + 0.3 * math.sin(progress * math.pi * 2 + i));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width * (_isNight ? 0.78 : 0.72), y),
              width: w,
              height: 3),
          const Radius.circular(2),
        ),
        Paint()..color = glint.withOpacity(0.22),
      );
    }
  }

  void _paintReeds(Canvas canvas, Size size, double horizon) {
    final Color reed =
        _isNight ? const Color(0xFF13322C) : MosesColors.reedDark;
    for (int i = 0; i < 16; i++) {
      final double x = (i / 15) * size.width;
      // Taller at the edges, so the middle of the frame stays readable for
      // the figures the story pops on top of it.
      final double edge = (x / size.width - 0.5).abs() * 2;
      final double h = size.height * (0.06 + 0.16 * edge);
      final double sway =
          math.sin(progress * math.pi * 2 + i * 0.8) * size.width * 0.008;
      final double base = horizon + size.height * 0.06;
      canvas.drawLine(
        Offset(x, base),
        Offset(x + sway, base - h),
        Paint()
          ..color = reed.withOpacity(0.9)
          ..strokeWidth = math.max(1.5, size.width * 0.008)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x + sway, base - h),
        math.max(1.5, size.width * 0.009),
        Paint()..color = reed.withOpacity(0.95),
      );
    }
  }

  void _paintBrickPits(Canvas canvas, Size size, double horizon) {
    // Rows of mud bricks laid out to dry — the work itself, without showing
    // anyone being hurt doing it.
    final Paint brick = Paint()
      ..color = const Color(0xFF9C6B43).withOpacity(0.75);
    for (int row = 0; row < 3; row++) {
      final double y = horizon + size.height * (0.10 + row * 0.09);
      final double w = size.width * (0.05 + row * 0.012);
      for (int i = 0; i < 6; i++) {
        final double x =
            size.width * 0.08 + i * (w + size.width * 0.025) + row * 8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, size.height * 0.028),
            const Radius.circular(2),
          ),
          brick,
        );
      }
    }
  }

  void _paintLamp(Canvas canvas, Size size, double horizon) {
    // One oil lamp, flickering — the whole reason these beats are warm rather
    // than only dark.
    final double flicker = 0.82 + 0.18 * math.sin(progress * math.pi * 2 * 3.3);
    final Offset flame =
        Offset(size.width * 0.18, horizon - size.height * 0.02);
    canvas.drawCircle(
      flame,
      size.width * 0.22 * flicker,
      Paint()
        ..color = const Color(0xFFFFC46B).withOpacity(0.20 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
    canvas.drawCircle(
      flame,
      size.width * 0.02 * flicker,
      Paint()..color = const Color(0xFFFFE9B0),
    );
  }

  void _paintRays(Canvas canvas, Size size) {
    final Offset from = Offset(size.width * 0.72, size.height * 0.30);
    for (int i = 0; i < 9; i++) {
      final double a = i * (math.pi * 2 / 9) + progress * 0.35;
      final Offset to =
          from + Offset(math.cos(a), math.sin(a)) * size.longestSide * 0.55;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = const Color(0xFFFFF3C4).withOpacity(0.10)
          ..strokeWidth = 10,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MosesIntroPainter old) =>
      old.progress != progress ||
      old.era != era ||
      old.entrance != entrance ||
      old.figures != figures;
}
