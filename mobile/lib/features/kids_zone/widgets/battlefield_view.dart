import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/siddim_battle_level.dart';

/// Animated Siddim valley backdrop — dusk sky, ridges, and marching silhouettes.
///
/// Used by the Battle of Siddim introduction; the archery rounds paint their own
/// field on top of the same colour language.
class BattlefieldView extends StatefulWidget {
  const BattlefieldView({
    super.key,
    required this.layers,
    this.marchingSoldiers = 0,
    this.showVictoryRainbow = false,
  });

  final List<BattleVisualLayer> layers;
  final int marchingSoldiers;
  final bool showVictoryRainbow;

  @override
  State<BattlefieldView> createState() => _BattlefieldViewState();
}

class _BattlefieldViewState extends State<BattlefieldView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _march;

  @override
  void initState() {
    super.initState();
    _march = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _march.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the scene repaints every frame, and without this the
    // HUD drawn over it is re-rasterised at the same rate for no reason.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double w = constraints.maxWidth;
          final double h = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(gradient: SiddimColors.duskGradient),
              ),
              AnimatedBuilder(
                animation: _march,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _ValleyPainter(
                      progress: _march.value,
                      marchingSoldiers: widget.marchingSoldiers,
                      showVictoryRainbow: widget.showVictoryRainbow,
                    ),
                  );
                },
              ),
              for (int i = 0; i < widget.layers.length; i++)
                _PoppingLayer(
                  key: ValueKey<String>(
                    'siddim-layer-$i-${widget.layers[i].icon.codePoint}',
                  ),
                  layer: widget.layers[i],
                  maxWidth: w,
                  maxHeight: h,
                  delayMs: i * 200,
                ),
            ],
          );
        },
      ),
    );
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

  final BattleVisualLayer layer;
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

class _ValleyPainter extends CustomPainter {
  _ValleyPainter({
    required this.progress,
    required this.marchingSoldiers,
    required this.showVictoryRainbow,
  });

  /// 0→1 loop driving the marching silhouettes.
  final double progress;
  final int marchingSoldiers;
  final bool showVictoryRainbow;

  @override
  void paint(Canvas canvas, Size size) {
    final double ridgeY = size.height * 0.62;
    final double groundY = size.height * 0.78;

    if (showVictoryRainbow) {
      paintVictoryRainbow(canvas, size);
    }

    // Far ridge.
    final Path far = Path()..moveTo(0, ridgeY);
    far.quadraticBezierTo(size.width * 0.22, ridgeY - size.height * 0.12,
        size.width * 0.46, ridgeY - size.height * 0.02);
    far.quadraticBezierTo(size.width * 0.72, ridgeY + size.height * 0.06,
        size.width, ridgeY - size.height * 0.06);
    far.lineTo(size.width, size.height);
    far.lineTo(0, size.height);
    far.close();
    canvas.drawPath(
      far,
      Paint()..color = SiddimColors.ridgeFar.withOpacity(0.85),
    );

    // Near ground.
    final Path near = Path()..moveTo(0, groundY);
    near.quadraticBezierTo(size.width * 0.35, groundY - size.height * 0.05,
        size.width * 0.68, groundY + size.height * 0.02);
    near.quadraticBezierTo(size.width * 0.86, groundY + size.height * 0.05,
        size.width, groundY - size.height * 0.01);
    near.lineTo(size.width, size.height);
    near.lineTo(0, size.height);
    near.close();
    canvas.drawPath(near, Paint()..color = SiddimColors.sand);

    // Tar pits — the valley "was full of tar pits" (Genesis 14:10).
    final Paint tar = Paint()..color = const Color(0xFF3E2723).withOpacity(0.5);
    for (final double x in <double>[0.18, 0.52, 0.83]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.90),
          width: size.width * 0.16,
          height: size.height * 0.035,
        ),
        tar,
      );
    }

    _paintMarchers(canvas, size, ridgeY);
  }

  void _paintMarchers(Canvas canvas, Size size, double ridgeY) {
    if (marchingSoldiers <= 0) return;

    final Paint body = Paint()..color = const Color(0xFF2E2545).withOpacity(0.75);
    final double figureHeight = size.height * 0.075;

    for (int i = 0; i < marchingSoldiers; i++) {
      final double offset = (progress + i / marchingSoldiers) % 1.0;
      final double x = size.width * (1.05 - offset * 1.2);
      final double bob = math.sin((progress * 2 * math.pi * 6) + i) * 2.0;
      final double baseY = ridgeY + size.height * 0.06 + bob;

      // Body.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - figureHeight, figureHeight * 0.42,
              figureHeight * 0.72),
          Radius.circular(figureHeight * 0.18),
        ),
        body,
      );
      // Head.
      canvas.drawCircle(
        Offset(x + figureHeight * 0.21, baseY - figureHeight * 1.08),
        figureHeight * 0.19,
        body,
      );
      // Spear.
      canvas.drawLine(
        Offset(x + figureHeight * 0.52, baseY - figureHeight * 1.35),
        Offset(x + figureHeight * 0.52, baseY),
        Paint()
          ..color = body.color
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ValleyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.marchingSoldiers != marchingSoldiers ||
        oldDelegate.showVictoryRainbow != showVictoryRainbow;
  }
}

/// Victory arc painted behind the ridges when the King's Round is won.
void paintVictoryRainbow(Canvas canvas, Size size) {
  const List<Color> colors = <Color>[
    Color(0xFFE53935),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
  ];
  final Rect arcRect = Rect.fromLTWH(
    size.width * 0.05,
    size.height * 0.10,
    size.width * 0.9,
    size.width * 0.9,
  );
  for (int i = 0; i < colors.length; i++) {
    canvas.drawArc(
      arcRect.deflate(i * 9.0),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = colors[i].withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );
  }
}
