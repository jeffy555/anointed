import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Vivid multi-color gradient behind every screen.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradient =
        isDark ? AppColors.backgroundGradientDark : AppColors.backgroundGradientLight;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const <double>[0.0, 0.55, 1.0],
                colors: gradient,
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -30,
            child: _Orb(colors: const <Color>[AppColors.primary, AppColors.primaryLight], opacity: isDark ? 0.4 : 0.55, size: 240),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _Orb(colors: const <Color>[AppColors.secondary, Color(0xFF651FFF)], opacity: isDark ? 0.35 : 0.5, size: 200),
          ),
          Positioned(
            bottom: 120,
            right: -20,
            child: _Orb(colors: const <Color>[AppColors.tertiary, AppColors.accent], opacity: isDark ? 0.32 : 0.48, size: 160),
          ),
          Positioned(
            bottom: -50,
            left: 30,
            child: _Orb(colors: const <Color>[AppColors.primary, AppColors.secondary], opacity: isDark ? 0.28 : 0.42, size: 190),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.colors,
    required this.opacity,
    required this.size,
  });

  final List<Color> colors;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.map((Color c) => c.withOpacity(opacity)).toList(),
        ),
      ),
    );
  }
}
