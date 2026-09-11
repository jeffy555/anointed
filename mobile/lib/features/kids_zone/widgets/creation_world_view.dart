import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../kids_zone_tokens.dart';
import '../levels/genesis_creation_level.dart';

/// The Creation world, painted day by day.
///
/// The scene is cumulative: whatever God makes on a day appears that day and
/// stays for every day after. When [day] changes the new elements animate in and
/// the sky lerps from the previous day's palette to the new one — so Day 1 is
/// literally watched: formless darkness brightening as light arrives.
///
/// Days are 0 (before Day One) through 7.
class CreationWorldView extends StatefulWidget {
  const CreationWorldView({
    super.key,
    required this.day,
    this.showRainbow = false,
  });

  final int day;
  final bool showRainbow;

  @override
  State<CreationWorldView> createState() => _CreationWorldViewState();
}

class _CreationWorldViewState extends State<CreationWorldView>
    with TickerProviderStateMixin {
  /// Seconds of ambient motion per full loop of drift/twinkle.
  static const double _ambientPeriod = 12;

  /// Seconds per breath of the Day 7 rest glow.
  static const double _restBreath = 4.5;

  /// How much of the world's motion survives the sabbath. Not zero — a resting
  /// world should still feel alive, just barely stirring.
  static const double _restMotion = 0.06;

  /// Drives the arrival of everything made on the current day.
  late final AnimationController _reveal;

  late final Ticker _ticker;

  /// Repaints the scene without rebuilding anything above the CustomPaint.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;

  /// Ambient motion, accumulated rather than looped, so its rate can ease down
  /// on Day 7 without the world jumping back to the start of a cycle.
  double _phase = 0;

  /// Real time, unscaled — the rest glow keeps breathing after the drifting
  /// has stilled.
  double _restClock = 0;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      value: 1,
    );
    _ticker = createTicker(_onTick)..start();
    _reveal.forward(from: 0);
  }

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    _phase += dt / _ambientPeriod * _motionScale;
    _restClock += dt;
    _frame.value++;
  }

  /// 0 before the seventh day, easing to 1 as rest settles in.
  double get _rest => widget.day >= 7
      ? Curves.easeInOut.transform(_reveal.value)
      : 0.0;

  double get _motionScale => 1 - _rest * (1 - _restMotion);

  @override
  void didUpdateWidget(covariant CreationWorldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _reveal.forward(from: 0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _reveal.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_reveal, _frame]),
        builder: (BuildContext context, _) {
          return CustomPaint(
            painter: _CreationScenePainter(
              day: widget.day,
              reveal: Curves.easeInOut.transform(_reveal.value),
              ambient: _phase,
              restPulse: 0.5 +
                  0.5 * math.sin(_restClock / _restBreath * 2 * math.pi),
              showRainbow: widget.showRainbow,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// Scene geometry, as fractions of the view height.
///
/// Exposed so tests can assert that sea creatures stay in the sea and land
/// creatures stay on the land.
class CreationSceneLayout {
  const CreationSceneLayout._();

  /// Where sky meets sea.
  static const double horizon = 0.56;

  /// Top of the foreground land; the sea shows between [horizon] and here.
  static const double shore = 0.74;

  /// Middle of the visible water band, where fish swim.
  static const double fishBand = (horizon + shore) / 2;
}

/// Sky colours for each day, top to bottom.
const Map<int, List<Color>> _skies = <int, List<Color>>{
  // Before Day One — "darkness was over the surface of the deep".
  0: <Color>[Color(0xFF04050B), Color(0xFF080C18), Color(0xFF05070E)],
  // Day 1 — light, but no sun yet.
  1: <Color>[Color(0xFF14356B), Color(0xFF4E8FC4), Color(0xFFBFE0F2)],
  2: <Color>[Color(0xFF17538F), Color(0xFF5FA6D8), Color(0xFFC7E7F7)],
  3: <Color>[Color(0xFF1A5C99), Color(0xFF6FB2DF), Color(0xFFD2ECF9)],
  4: <Color>[Color(0xFF0F3E75), Color(0xFF4C93CC), Color(0xFFC3E4F6)],
  5: <Color>[Color(0xFF1A5C99), Color(0xFF6FB2DF), Color(0xFFD2ECF9)],
  6: <Color>[Color(0xFF23639E), Color(0xFF7BBBE3), Color(0xFFDCF0FA)],
  // Day 7 — dusk over a finished world. Deliberately the darkest sky since
  // Day 1, so the week closes where it began, but at peace rather than in void.
  7: <Color>[Color(0xFF1E3A66), Color(0xFFD07C46), Color(0xFFF6D2A2)],
};

/// The sky palette for a given day, top to bottom.
///
/// Exposed so the story's own arc can be asserted — Day 7 has to read as dusk,
/// not as another bright working day.
List<Color> creationSkyFor(int day) => _skies[day.clamp(0, 7)]!;

class _CreationScenePainter extends CustomPainter {
  _CreationScenePainter({
    required this.day,
    required this.reveal,
    required this.ambient,
    required this.restPulse,
    required this.showRainbow,
  });

  final int day;

  /// 0→1 arrival of whatever is new on [day].
  final double reveal;

  /// Accumulated idle-motion clock, in loops. Slows to a near stop on Day 7.
  final double ambient;

  /// 0→1→0 breath driving the sabbath glow.
  final double restPulse;

  final bool showRainbow;

  /// How present something introduced on [introducedOn] should be: fully here
  /// on later days, arriving today, absent before.
  double _in(int introducedOn) {
    if (day > introducedOn) return 1;
    if (day == introducedOn) return reveal;
    return 0;
  }

  double get _horizon => CreationSceneLayout.horizon;

  double get _shore => CreationSceneLayout.shore;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    if (day == 1) _paintFirstLight(canvas, size);
    _paintStars(canvas, size);
    _paintCelestials(canvas, size);
    if (showRainbow) _paintRainbow(canvas, size);
    _paintClouds(canvas, size);
    _paintWater(canvas, size);
    _paintLand(canvas, size);
    _paintPlants(canvas, size);
    _paintFish(canvas, size);
    _paintBirds(canvas, size);
    _paintAnimals(canvas, size);
    _paintPeople(canvas, size);
    if (day >= 7) _paintRestGlow(canvas, size);
  }

  // ------------------------------------------------------------------- sky

  void _paintSky(Canvas canvas, Size size) {
    final List<Color> to = _skies[day.clamp(0, 7)]!;
    final List<Color> from = _skies[(day - 1).clamp(0, 7)]!;

    // Lerping from yesterday's sky is what makes Day 1 read as darkness giving
    // way to light rather than a hard cut.
    final List<Color> sky = <Color>[
      for (int i = 0; i < 3; i++) Color.lerp(from[i], to[i], reveal)!,
    ];

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  /// Day 1 — light itself, before there is any sun to carry it.
  void _paintFirstLight(Canvas canvas, Size size) {
    // Brightest mid-transition, then settles into the day.
    final double burst = math.sin(reveal * math.pi);
    final Offset centre = Offset(size.width * 0.5, size.height * 0.34);
    final double radius = size.width * (0.25 + reveal * 0.85);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFFDF0).withOpacity(0.90 * burst + 0.10 * reveal),
            const Color(0xFFFFF3C4).withOpacity(0.45 * burst),
            const Color(0x00FFF3C4),
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  void _paintStars(Canvas canvas, Size size) {
    final double a = _in(4);
    if (a <= 0) return;

    for (int i = 0; i < 34; i++) {
      // Deterministic scatter — stars must not jump between frames.
      final double fx = ((i * 73) % 100) / 100;
      final double fy = ((i * 37) % 100) / 100;
      final double x = fx * size.width;
      final double y = fy * size.height * 0.46;

      final double twinkle =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin((ambient * 2 * math.pi) + i));
      final double r = (i % 3 == 0 ? 1.7 : 1.1) * (0.6 + 0.4 * twinkle);

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withOpacity(0.85 * a * twinkle),
      );
    }
  }

  /// Sun and moon — made on Day 4, so days 1–3 have light without luminaries.
  void _paintCelestials(Canvas canvas, Size size) {
    final double a = _in(4);
    if (a <= 0) return;

    // Sun, upper right, with a soft corona.
    final Offset sun = Offset(size.width * 0.74, size.height * 0.20);
    final double sunR = size.width * 0.075 * a;
    canvas.drawCircle(
      sun,
      sunR * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF4C2).withOpacity(0.55 * a),
            const Color(0x00FFF4C2),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR * 3.2)),
    );
    canvas.drawCircle(
      sun,
      sunR,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color.lerp(const Color(0xFFFFFBE8), const Color(0xFFFFD54F), 0.2)!,
            const Color(0xFFFFB300),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR)),
    );

    // Moon, upper left — a crescent carved by an offset circle.
    final Offset moon = Offset(size.width * 0.18, size.height * 0.14);
    final double moonR = size.width * 0.045 * a;
    canvas.saveLayer(Rect.fromCircle(center: moon, radius: moonR * 2), Paint());
    canvas.drawCircle(
      moon,
      moonR,
      Paint()..color = const Color(0xFFF2F4FF).withOpacity(0.92 * a),
    );
    canvas.drawCircle(
      moon.translate(moonR * 0.55, -moonR * 0.30),
      moonR * 0.92,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  void _paintClouds(Canvas canvas, Size size) {
    final double a = _in(2);
    if (a <= 0) return;

    final Paint paint = Paint()..color = Colors.white.withOpacity(0.80 * a);
    // Two banks drifting at different speeds.
    for (final (double baseX, double y, double scale, double speed)
        in <(double, double, double, double)>[
      (0.10, 0.16, 1.0, 0.35),
      (0.58, 0.26, 0.72, 0.22),
    ]) {
      final double x =
          ((baseX + ambient * speed) % 1.25 - 0.15) * size.width;
      final double w = size.width * 0.20 * scale;
      final double h = size.height * 0.045 * scale;
      final double cy = size.height * y;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, cy), width: w, height: h),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + w * 0.28, cy - h * 0.35),
          width: w * 0.72,
          height: h * 0.95,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - w * 0.30, cy + h * 0.10),
          width: w * 0.60,
          height: h * 0.80,
        ),
        paint,
      );
    }
  }

  // ----------------------------------------------------------------- water

  void _paintWater(Canvas canvas, Size size) {
    final double a = _in(2);
    if (a <= 0) return;

    // Day 2 separates the waters: the horizon travels up from the foot of the
    // frame until sky and sea are divided. Water is drawn all the way down —
    // the land painted after this covers the foreground.
    final double top = size.height * (1 - a * (1 - _horizon));
    final Rect rect = Rect.fromLTRB(0, top, size.width, size.height);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF3E8FC4), Color(0xFF14486F)],
        ).createShader(rect),
    );

    // Drifting highlights, kept inside the visible sea band.
    final Paint crest = Paint()
      ..color = Colors.white.withOpacity(0.22 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int row = 0; row < 3; row++) {
      final double y = top + size.height * (0.025 + row * 0.045);
      if (y > size.height) break;
      final double shift =
          ((ambient + row * 0.31) % 1.0) * size.width * 0.35;
      final Path wave = Path();
      for (double x = -size.width * 0.35 + shift;
          x < size.width;
          x += size.width * 0.24) {
        wave.moveTo(x, y);
        wave.quadraticBezierTo(
          x + size.width * 0.06,
          y - size.height * 0.014,
          x + size.width * 0.12,
          y,
        );
      }
      canvas.drawPath(wave, crest);
    }
  }

  // ------------------------------------------------------------------ land

  Path _hillPath(Size size, double top, double lift) {
    final double y = size.height * top + (1 - lift) * size.height * 0.35;
    final Path path = Path()..moveTo(0, y + size.height * 0.05);
    path.quadraticBezierTo(
      size.width * 0.22,
      y - size.height * 0.07,
      size.width * 0.48,
      y + size.height * 0.01,
    );
    path.quadraticBezierTo(
      size.width * 0.74,
      y + size.height * 0.09,
      size.width,
      y - size.height * 0.02,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  void _paintLand(Canvas canvas, Size size) {
    final double a = _in(3);
    if (a <= 0) return;

    // Far ridge, then the near meadow — dry ground rising out of the water,
    // leaving the sea visible behind it.
    canvas.drawPath(
      _hillPath(size, _shore - 0.03, a),
      Paint()..color = const Color(0xFF4E7A46).withOpacity(a),
    );
    canvas.drawPath(
      _hillPath(size, _shore + 0.05, a),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF6FAE58).withOpacity(a),
            const Color(0xFF3F7A3A).withOpacity(a),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintPlants(Canvas canvas, Size size) {
    final double a = _in(3);
    if (a <= 0) return;

    // Trees scale up from the ground as they grow.
    for (final (double fx, double fy, double scale)
        in <(double, double, double)>[
      (0.13, 0.89, 1.00),
      (0.30, 0.94, 0.72),
      (0.83, 0.90, 0.88),
    ]) {
      _tree(canvas, size, fx, fy, scale * a);
    }

    // Low flowers along the meadow.
    for (int i = 0; i < 6; i++) {
      final double x = size.width * (0.08 + i * 0.155);
      final double y = size.height * (0.95 + (i.isEven ? 0.025 : 0.0));
      final double r = size.width * 0.010 * a;
      if (r <= 0) continue;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = (i.isEven
                  ? const Color(0xFFEF6D8A)
                  : const Color(0xFFFFD35C))
              .withOpacity(a),
      );
    }
  }

  void _tree(Canvas canvas, Size size, double fx, double fy, double grow) {
    if (grow <= 0) return;
    final double x = size.width * fx;
    final double baseY = size.height * fy;
    final double h = size.height * 0.20 * grow;
    final double w = size.width * 0.085 * grow;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w * 0.09, baseY - h * 0.45, w * 0.18, h * 0.45),
        Radius.circular(w * 0.09),
      ),
      Paint()..color = const Color(0xFF6B4A2F),
    );

    final Paint canopy = Paint()..color = const Color(0xFF3E8E41);
    canvas.drawCircle(Offset(x, baseY - h * 0.62), w * 0.44, canopy);
    canvas.drawCircle(
      Offset(x - w * 0.30, baseY - h * 0.48),
      w * 0.34,
      canopy,
    );
    canvas.drawCircle(
      Offset(x + w * 0.30, baseY - h * 0.50),
      w * 0.34,
      canopy,
    );
    canvas.drawCircle(
      Offset(x + w * 0.06, baseY - h * 0.78),
      w * 0.30,
      Paint()..color = const Color(0xFF57A85A),
    );
  }

  // -------------------------------------------------------- living things

  void _paintFish(Canvas canvas, Size size) {
    final double a = _in(5);
    if (a <= 0) return;

    // Confined to the water between the horizon and the shore — fish must never
    // end up drifting across the meadow.
    const double band = CreationSceneLayout.fishBand;
    for (int i = 0; i < 3; i++) {
      final double drift = (ambient + i * 0.33) % 1.0;
      final double x = (0.08 + drift * 0.84) * size.width;
      final double y = size.height *
          (band + 0.030 * math.sin((drift * 2 * math.pi) + i));
      final double r = size.width * 0.020 * a;
      if (r <= 0) continue;

      final Paint paint = Paint()
        ..color = (i.isEven
                ? const Color(0xFFFFB74D)
                : const Color(0xFF80DEEA))
            .withOpacity(a);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 2.4, height: r * 1.3),
        paint,
      );
      final Path tail = Path()
        ..moveTo(x - r * 1.2, y)
        ..lineTo(x - r * 1.9, y - r * 0.7)
        ..lineTo(x - r * 1.9, y + r * 0.7)
        ..close();
      canvas.drawPath(tail, paint);
    }
  }

  void _paintBirds(Canvas canvas, Size size) {
    final double a = _in(5);
    if (a <= 0) return;

    final Paint stroke = Paint()
      ..color = const Color(0xFF2A2E45).withOpacity(0.72 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final double drift = (ambient * 0.7 + i * 0.27) % 1.0;
      final double x = (1.05 - drift * 1.15) * size.width;
      final double y = size.height *
          (0.16 + 0.06 * math.sin((drift * 2 * math.pi) + i * 1.7) + i * 0.035);
      final double w = size.width * 0.030;
      // A gentle wing-beat.
      final double flap =
          w * 0.32 * (0.55 + 0.45 * math.sin(ambient * 12 * math.pi + i));

      final Path bird = Path()
        ..moveTo(x - w, y)
        ..quadraticBezierTo(x - w * 0.5, y - flap, x, y)
        ..quadraticBezierTo(x + w * 0.5, y - flap, x + w, y);
      canvas.drawPath(bird, stroke);
    }
  }

  void _paintAnimals(Canvas canvas, Size size) {
    final double a = _in(6);
    if (a <= 0) return;

    // Two grazing silhouettes on the meadow.
    for (final (double fx, double fy, double scale, Color colour)
        in <(double, double, double, Color)>[
      (0.45, 0.90, 1.0, Color(0xFF8D6E63)),
      (0.63, 0.95, 0.78, Color(0xFFA1887F)),
    ]) {
      final double w = size.width * 0.085 * scale * a;
      final double h = size.height * 0.045 * scale * a;
      if (w <= 0) continue;
      final double x = size.width * fx;
      final double y = size.height * fy;
      final Paint paint = Paint()..color = colour.withOpacity(a);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        paint,
      );
      canvas.drawCircle(Offset(x + w * 0.44, y - h * 0.45), h * 0.42, paint);
      final Paint leg = Paint()
        ..color = colour.withOpacity(a)
        ..strokeWidth = math.max(1.5, w * 0.07)
        ..strokeCap = StrokeCap.round;
      for (final double lx in <double>[-0.28, 0.24]) {
        canvas.drawLine(
          Offset(x + w * lx, y + h * 0.35),
          Offset(x + w * lx, y + h * 0.95),
          leg,
        );
      }
    }
  }

  void _paintPeople(Canvas canvas, Size size) {
    final double a = _in(6);
    if (a <= 0) return;

    for (final (double fx, Color robe) in <(double, Color)>[
      (0.20, Color(0xFFFFE0B2)),
      (0.27, Color(0xFFD7CCF5)),
    ]) {
      final double x = size.width * fx;
      final double baseY = size.height * 0.96;
      final double h = size.height * 0.11 * a;
      if (h <= 0) continue;
      final double w = size.width * 0.030 * a;

      final Path body = Path()
        ..moveTo(x - w, baseY)
        ..lineTo(x - w * 0.45, baseY - h * 0.72)
        ..lineTo(x + w * 0.45, baseY - h * 0.72)
        ..lineTo(x + w, baseY)
        ..close();
      canvas.drawPath(body, Paint()..color = robe.withOpacity(a));
      canvas.drawCircle(
        Offset(x, baseY - h * 0.86),
        w * 0.52,
        Paint()..color = const Color(0xFF6D4C41).withOpacity(a),
      );
    }
  }

  /// Day 7 — the sabbath. The climax of the week is stillness, so instead of
  /// adding another thing to the world this quiets it: a warm evening wash, the
  /// edges dimmed, and one slow breath of light over a world that is finished.
  void _paintRestGlow(Canvas canvas, Size size) {
    final double a = _in(7);
    if (a <= 0) return;

    final Rect rect = Offset.zero & size;

    // Evening settles over everything.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFFFFC07A).withOpacity(0.20 * a),
    );

    // Dim the edges so the eye rests toward the middle.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: <Color>[
            const Color(0x00000000),
            const Color(0xFF2A1B3D).withOpacity(0.34 * a),
          ],
          stops: const <double>[0.55, 1.0],
        ).createShader(rect),
    );

    // The only movement left: a slow breath of warmth, replacing the pop-and-
    // layer arrivals of the six working days.
    final Offset heart = Offset(size.width * 0.5, size.height * 0.44);
    final double radius = size.width * (0.42 + 0.06 * restPulse);
    canvas.drawCircle(
      heart,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF1CE)
                .withOpacity((0.10 + 0.12 * restPulse) * a),
            const Color(0x00FFF1CE),
          ],
        ).createShader(Rect.fromCircle(center: heart, radius: radius)),
    );
  }

  void _paintRainbow(Canvas canvas, Size size) {
    const List<Color> colors = <Color>[
      Color(0xFFE53935),
      Color(0xFFFF9800),
      Color(0xFFFFEB3B),
      Color(0xFF66BB6A),
      Color(0xFF42A5F5),
      Color(0xFF7E57C2),
    ];
    final Rect arc = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.10,
      size.width * 0.90,
      size.width * 0.90,
    );
    final double band = math.max(4.0, size.width * 0.022);
    for (int i = 0; i < colors.length; i++) {
      canvas.drawArc(
        arc.deflate(i * band * 0.85),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = colors[i].withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = band,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CreationScenePainter old) =>
      old.day != day ||
      old.reveal != reveal ||
      old.ambient != ambient ||
      old.restPulse != restPulse ||
      old.showRainbow != showRainbow;
}

/// Brief overlay when a Level 1 answer is correct.
class CreationCelebrationBurst extends StatefulWidget {
  const CreationCelebrationBurst({super.key, required this.type});

  final CreationCelebration type;

  @override
  State<CreationCelebrationBurst> createState() =>
      _CreationCelebrationBurstState();
}

class _CreationCelebrationBurstState extends State<CreationCelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (widget.type) {
      CreationCelebration.light =>
        (Icons.wb_sunny_rounded, const Color(0xFFFFD54F), 'Light shines!'),
      CreationCelebration.stars =>
        (Icons.star_rounded, const Color(0xFFFFF176), 'Stars twinkle!'),
      CreationCelebration.plants =>
        (Icons.park_rounded, const Color(0xFF66BB6A), 'Plants grow!'),
      CreationCelebration.water =>
        (Icons.water_rounded, const Color(0xFF29B6F6), 'Waters teem!'),
      CreationCelebration.animals =>
        (Icons.pets_rounded, const Color(0xFF8D6E63), 'Animals appear!'),
      CreationCelebration.people =>
        (Icons.person_rounded, const Color(0xFF5C6BC0), 'People created!'),
      CreationCelebration.rest =>
        (Icons.favorite_rounded, const Color(0xFFEC407A), 'Very good!'),
      CreationCelebration.rainbow =>
        (Icons.wb_sunny_rounded, const Color(0xFFAB47BC), 'Rainbow glory!'),
    };

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1)),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.4, end: 1.2).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 88, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style:
                  KidsZoneText.nunito(size: 20, weight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
