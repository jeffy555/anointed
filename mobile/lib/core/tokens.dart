import 'package:flutter/material.dart';

/// Bold arcade-style palette — high saturation, strong contrast, game energy.
class AppColors {
  const AppColors._();

  // Core brand
  static const Color primary = Color(0xFFFF6D00);
  static const Color primaryLight = Color(0xFFFF9100);
  static const Color primaryDark = Color(0xFFE65100);
  static const Color primaryContainer = Color(0xFFFFCC80);
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryLight = Color(0xFFB388FF);
  static const Color secondaryContainer = Color(0xFFD1C4E9);
  static const Color tertiary = Color(0xFF00B0FF);
  static const Color tertiaryContainer = Color(0xFF80D8FF);
  static const Color accent = Color(0xFFFF4081);

  // Surfaces
  static const Color surface = Color(0xFFFFF8F0);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1033);
  static const Color textSecondary = Color(0xFF5C5470);
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFAB00);
  static const Color locked = Color(0xFF607D8B);

  static const List<Color> backgroundGradientLight = <Color>[
    Color(0xFFFF8A65),
    Color(0xFFCE93D8),
    Color(0xFF4FC3F7),
  ];

  static const List<Color> backgroundGradientDark = <Color>[
    Color(0xFF0D0221),
    Color(0xFF261447),
    Color(0xFF0F3460),
  ];

  // Dark mode
  static const Color surfaceDark = Color(0xFF12082A);
  static const Color surfaceCardDark = Color(0xFF1E1040);
  static const Color surfaceElevatedDark = Color(0xFF2A1658);
  static const Color textPrimaryDark = Color(0xFFF5F0FF);
  static const Color textSecondaryDark = Color(0xFFB8AED0);
  static const Color primaryOnDark = Color(0xFFFF9100);
  static const Color primaryContainerDark = Color(0xFF4A2800);
  static const Color secondaryOnDark = Color(0xFFB388FF);
  static const Color secondaryContainerDark = Color(0xFF3D2066);
  static const Color tertiaryOnDark = Color(0xFF40C4FF);

  // Shared gradients
  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, primaryLight],
  );

  static const LinearGradient secondaryButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[secondary, Color(0xFF651FFF)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, secondary],
  );

  static const LinearGradient progressCardGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[primary, secondary],
  );

  static const LinearGradient unlockedNodeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, Color(0xFFFF4081)],
  );

  static const LinearGradient completedNodeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[successDark, success],
  );

  static const LinearGradient practiceNodeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[secondary, tertiary],
  );

  // Timer states
  static const Color timerNormal = textPrimary;
  static const Color timerNormalDark = textPrimaryDark;
  static const Color timerWarning = warning;
  static const Color timerCritical = error;
}

/// Family names of the fonts bundled in pubspec.yaml.
///
/// These are shipped assets, not runtime downloads. Referencing them by name
/// keeps every weight declared in one place: a style asking for a weight the
/// bundle does not carry falls back to the nearest one that it does, silently,
/// so the pubspec list is the contract.
class AnointedFonts {
  const AnointedFonts._();

  /// Kids Zone. Weights 600, 700, 800.
  static const String nunito = 'Nunito';

  /// Parchment Codex body and UI. Weights 400, 500, 600, 700, 800.
  static const String karla = 'Karla';

  /// Parchment Codex display. Weights 500, 600, 700.
  static const String cormorantGaramond = 'CormorantGaramond';
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double full = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(lg));
}

class AppTypeScale {
  const AppTypeScale._();

  static const double xs = 12;
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const double largeTextMultiplier = 1.25;
}

const double kMinTapTarget = 48;

Color timerColorFor(int secondsRemaining, {required bool isDark}) {
  if (secondsRemaining <= 5) return AppColors.timerCritical;
  if (secondsRemaining <= 10) return AppColors.timerWarning;
  return isDark ? AppColors.timerNormalDark : AppColors.timerNormal;
}
