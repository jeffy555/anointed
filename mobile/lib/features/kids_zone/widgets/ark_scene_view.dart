import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/noah_ark_level.dart';

/// Animated Noah's Ark backdrop — sky, rain, rising water, dove and rainbow.
///
/// The mood is driven by [ArkWeather] so one widget carries the whole story arc
/// from dry land to the covenant rainbow.
class ArkSceneView extends StatefulWidget {
  const ArkSceneView({
    super.key,
    required this.weather,
    this.layers = const <ArkVisualLayer>[],
  });

  final ArkWeather weather;
  final List<ArkVisualLayer> layers;

  @override
  State<ArkSceneView> createState() => _ArkSceneViewState();
}

class _ArkSceneViewState extends State<ArkSceneView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
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
              DecoratedBox(
                decoration: BoxDecoration(gradient: _skyFor(widget.weather)),
              ),
              AnimatedBuilder(
                animation: _loop,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _ArkScenePainter(
                      weather: widget.weather,
                      progress: _loop.value,
                    ),
                  );
                },
              ),
              for (int i = 0; i < widget.layers.length; i++)
                _PoppingLayer(
                  key: ValueKey<String>(
                    'ark-layer-$i-${widget.layers[i].icon.codePoint}',
                  ),
                  layer: widget.layers[i],
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  delayMs: i * 200,
                ),
            ],
          );
        },
      ),
    );
  }

  LinearGradient _skyFor(ArkWeather weather) {
    return switch (weather) {
      ArkWeather.calm || ArkWeather.building => ArkColors.skyGradient,
      ArkWeather.gathering => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF56779B), Color(0xFF9DBBD4), Color(0xFFE8D9B5)],
        ),
      ArkWeather.rain || ArkWeather.flood => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF2B3A47), Color(0xFF48606F), Color(0xFF6E8794)],
        ),
      ArkWeather.dove => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF5C7FA3), Color(0xFFA8C4DA), Color(0xFFF2E4C8)],
        ),
      ArkWeather.rainbow => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF6FA8DC), Color(0xFFBFDCF0), Color(0xFFF6EFD8)],
        ),
    };
  }
}

class _PoppingLayer extends StatefulWidget {
  const _PoppingLayer({
    super.key,
    required this.layer,
    required this.maxWidth,
    required this.maxHeight,
    required this.delayMs,
  });

  final ArkVisualLayer layer;
  final double maxWidth;
  final double maxHeight;
  final int delayMs;

  @override
  State<_PoppingLayer> createState() => _PoppingLayerState();
}

class _PoppingLayerState extends State<_PoppingLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.layer.top * widget.maxHeight,
      left: widget.layer.left * widget.maxWidth,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.layer.color.withOpacity(0.4),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            widget.layer.icon,
            size: widget.layer.size,
            color: widget.layer.color,
          ),
        ),
      ),
    );
  }
}

class _ArkScenePainter extends CustomPainter {
  _ArkScenePainter({required this.weather, required this.progress});

  final ArkWeather weather;

  /// 0→1 looping clock for rain, waves and the drifting dove.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (weather == ArkWeather.rainbow) _paintRainbow(canvas, size);

    final double waterTop = switch (weather) {
      ArkWeather.calm || ArkWeather.building => 0.92,
      ArkWeather.gathering => 0.88,
      ArkWeather.rain => 0.78,
      ArkWeather.flood => 0.55,
      ArkWeather.dove => 0.66,
      ArkWeather.rainbow => 0.82,
    };

    if (weather == ArkWeather.calm ||
        weather == ArkWeather.building ||
        weather == ArkWeather.gathering ||
        weather == ArkWeather.rainbow) {
      _paintLand(canvas, size, waterTop);
    }

    _paintWater(canvas, size, waterTop);

    if (weather == ArkWeather.rain || weather == ArkWeather.flood) {
      _paintRain(canvas, size);
    }
    if (weather == ArkWeather.dove) {
      _paintDoveTrail(canvas, size);
    }
  }

  void _paintLand(Canvas canvas, Size size, double waterTop) {
    final Path hill = Path()..moveTo(0, size.height * (waterTop - 0.02));
    hill.quadraticBezierTo(
      size.width * 0.25,
      size.height * (waterTop - 0.16),
      size.width * 0.52,
      size.height * (waterTop - 0.03),
    );
    hill.quadraticBezierTo(
      size.width * 0.78,
      size.height * (waterTop + 0.04),
      size.width,
      size.height * (waterTop - 0.06),
    );
    hill.lineTo(size.width, size.height);
    hill.lineTo(0, size.height);
    hill.close();
    canvas.drawPath(
      hill,
      Paint()..color = const Color(0xFF7E9E5B).withOpacity(0.9),
    );
  }

  void _paintWater(Canvas canvas, Size size, double waterTop) {
    final double top = size.height * waterTop;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, size.height - top),
      Paint()..color = ArkColors.water.withOpacity(0.92),
    );

    // Wave crests drifting sideways.
    final Paint crest = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int row = 0; row < 3; row++) {
      final double y = top + size.height * (0.02 + row * 0.05);
      if (y > size.height) break;
      final double shift = (progress + row * 0.33) % 1.0 * size.width * 0.4;
      final Path wave = Path();
      for (double x = -size.width * 0.4 + shift;
          x < size.width;
          x += size.width * 0.22) {
        wave.moveTo(x, y);
        wave.quadraticBezierTo(
          x + size.width * 0.055,
          y - size.height * 0.012,
          x + size.width * 0.11,
          y,
        );
      }
      canvas.drawPath(wave, crest);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final Paint drop = Paint()
      ..color = const Color(0xFFCFE4F5).withOpacity(0.65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const int drops = 60;
    for (int i = 0; i < drops; i++) {
      // Deterministic scatter so drops do not jitter between frames.
      final double seedX = ((i * 37) % 100) / 100;
      final double seedY = ((i * 61) % 100) / 100;
      final double y = ((seedY + progress * 2.2) % 1.0) * size.height;
      final double x = seedX * size.width + size.height * 0.02;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - size.height * 0.012, y + size.height * 0.045),
        drop,
      );
    }
  }

  void _paintDoveTrail(Canvas canvas, Size size) {
    final double t = progress;
    final Offset centre = Offset(
      size.width * (0.15 + t * 0.7),
      size.height * (0.30 - math.sin(t * math.pi) * 0.06),
    );
    final Paint sparkle = Paint()..color = Colors.white.withOpacity(0.5);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
        centre - Offset(size.width * 0.035 * i, -size.height * 0.006 * i),
        3.0 - i * 0.5,
        sparkle,
      );
    }
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
      size.width * 0.04,
      size.height * 0.08,
      size.width * 0.92,
      size.width * 0.92,
    );
    for (int i = 0; i < colors.length; i++) {
      canvas.drawArc(
        arc.deflate(i * 9.0),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = colors[i].withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArkScenePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.weather != weather;
}
