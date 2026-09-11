import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/map/parchment_codex_tokens.dart';

/// Level-complete celebration — animated trophy with confetti burst (design-spec §1D).
class CelebrationAnimation extends StatefulWidget {
  const CelebrationAnimation({super.key, this.size = 120});

  final double size;

  @override
  State<CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<CelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.4,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int i = 0; i < 12; i++)
                _ConfettiPiece(
                  index: i,
                  progress: _controller.value,
                  radius: widget.size * 0.72,
                ),
              Transform.scale(
                scale: 1.0 + math.sin(_controller.value * math.pi * 2) * 0.06,
                child: child,
              ),
            ],
          );
        },
        child: _TrophyBadge(size: widget.size),
      ),
    );
  }
}

class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            ParchmentColors.goldLight,
            ParchmentColors.gold,
            ParchmentColors.brown,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ParchmentColors.gold.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: ParchmentColors.cream, width: 3),
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: size * 0.52,
        color: ParchmentColors.cream,
      ),
    );
  }
}

class _ConfettiPiece extends StatelessWidget {
  const _ConfettiPiece({
    required this.index,
    required this.progress,
    required this.radius,
  });

  final int index;
  final double progress;
  final double radius;

  static const List<Color> _colors = <Color>[
    ParchmentColors.gold,
    ParchmentColors.goldLight,
    ParchmentColors.current,
    ParchmentColors.brown,
    ParchmentColors.ink,
  ];

  @override
  Widget build(BuildContext context) {
    final double angle = (index / 12) * math.pi * 2 + progress * math.pi * 2;
    final double wave = math.sin(progress * math.pi * 4 + index);
    final double distance = radius * (0.55 + 0.25 * wave);
    final double x = math.cos(angle) * distance;
    final double y = math.sin(angle) * distance * 0.75 - radius * 0.08;
    final Color color = _colors[index % _colors.length];

    return Transform.translate(
      offset: Offset(x, y),
      child: Transform.rotate(
        angle: angle + progress * math.pi,
        child: Container(
          width: index.isEven ? 8 : 6,
          height: index.isEven ? 6 : 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
