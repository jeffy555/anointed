import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Parchment Codex level map design tokens (handoff direction 1a).
abstract final class ParchmentColors {
  static const Color page = Color(0xFFF7F0E1);
  static const Color ink = Color(0xFF241D14);
  static const Color gold = Color(0xFFA98432);
  static const Color goldLight = Color(0xFFE0B75E);
  static const Color goldPale = Color(0xFFF2D79A);
  static const Color cream = Color(0xFFFFFAF0);
  static const Color creamDark = Color(0xFFEFE3CA);
  static const Color strip = Color(0xFFF2E7D2);
  static const Color lockedFill = Color(0xFFECE0C9);
  static const Color current = Color(0xFFD97B2B);
  static const Color currentShadow = Color(0xFFA1521A);
  static const Color brown = Color(0xFF6D5526);

  static Color inkMuted([double opacity = 0.45]) =>
      ink.withOpacity(opacity);

  static Color inkBorder([double opacity = 0.09]) =>
      ink.withOpacity(opacity);

  static Color parchmentMuted([double opacity = 0.7]) =>
      page.withOpacity(opacity);
}

abstract final class ParchmentText {
  static TextStyle karla({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
  }) {
    return TextStyle(
      fontFamily: AnointedFonts.karla,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ParchmentColors.ink,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle cormorant({
    double size = 21,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: AnointedFonts.cormorantGaramond,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ParchmentColors.ink,
      height: height,
    );
  }
}
