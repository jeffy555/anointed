import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Visual tokens for Kids Zone — playful sky-world, distinct from Parchment Codex.
class KidsZoneColors {
  const KidsZoneColors._();

  static const Color skyTop = Color(0xFF87CEEB);
  static const Color skyBottom = Color(0xFFE0F7FA);
  static const Color grass = Color(0xFF81C784);
  static const Color cloud = Color(0xFFFFFFFF);
  static const Color sun = Color(0xFFFFD54F);
  static const Color ink = Color(0xFF1A237E);
  static const Color inkMuted = Color(0xFF5C6BC0);
  static const Color card = Color(0xFFFFFFFF);
  static const Color star = Color(0xFFFFC107);

  static LinearGradient get skyGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[skyTop, skyBottom],
      );
}

class KidsZoneText {
  const KidsZoneText._();

  static TextStyle nunito({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = KidsZoneColors.ink,
  }) {
    return TextStyle(
      fontFamily: AnointedFonts.nunito,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}
