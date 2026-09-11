import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Bold arcade-style Material 3 theme.
class AppTheme {
  const AppTheme._();

  static const String? _displayFontFamily = null;
  static const String? _bodyFontFamily = null;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.secondary,
          tertiary: AppColors.tertiary,
          onTertiary: Colors.white,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: Color(0xFF01579B),
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceElevated,
          error: AppColors.error,
          onError: Colors.white,
        ),
        cardColor: AppColors.surfaceCard,
        elevatedSurface: AppColors.surfaceElevated,
        secondaryText: AppColors.textSecondary,
        systemOverlay: SystemUiOverlayStyle.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: AppColors.primaryOnDark,
          onPrimary: Color(0xFF3E1500),
          primaryContainer: AppColors.primaryContainerDark,
          onPrimaryContainer: AppColors.primaryOnDark,
          secondary: AppColors.secondaryOnDark,
          onSecondary: Color(0xFF2A1050),
          secondaryContainer: AppColors.secondaryContainerDark,
          onSecondaryContainer: AppColors.secondaryOnDark,
          tertiary: AppColors.tertiaryOnDark,
          onTertiary: Color(0xFF003258),
          tertiaryContainer: Color(0xFF004A77),
          onTertiaryContainer: AppColors.tertiaryOnDark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.textPrimaryDark,
          surfaceContainerHighest: AppColors.surfaceElevatedDark,
          error: Color(0xFFFF5252),
          onError: Color(0xFF3E0000),
        ),
        cardColor: AppColors.surfaceCardDark,
        elevatedSurface: AppColors.surfaceElevatedDark,
        secondaryText: AppColors.textSecondaryDark,
        systemOverlay: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color cardColor,
    required Color elevatedSurface,
    required Color secondaryText,
    required SystemUiOverlayStyle systemOverlay,
  }) {
    final TextTheme text = _textTheme(scheme.onSurface, secondaryText);
    final bool isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      fontFamily: _bodyFontFamily,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: scheme.secondary.withOpacity(0.4),
        scrolledUnderElevation: 4,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: text.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 12,
        shadowColor: scheme.secondary.withOpacity(0.4),
        indicatorColor: scheme.primary.withOpacity(isLight ? 0.3 : 0.38),
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: AppTypeScale.xs,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : secondaryText,
            fontFamily: _bodyFontFamily,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : secondaryText,
            size: 26,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primary.withOpacity(0.35),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 28),
        unselectedIconTheme: IconThemeData(color: secondaryText),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: AppTypeScale.xs,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: secondaryText,
          fontSize: AppTypeScale.xs,
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: isLight ? 6 : 3,
        shadowColor: scheme.secondary.withOpacity(0.3),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: scheme.secondary.withOpacity(isLight ? 0.3 : 0.4), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(kMinTapTarget),
          elevation: 6,
          shadowColor: scheme.primary.withOpacity(0.55),
          textStyle: TextStyle(
            fontSize: AppTypeScale.md,
            fontWeight: FontWeight.w800,
            fontFamily: _bodyFontFamily,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTapTarget),
          foregroundColor: scheme.secondary,
          backgroundColor: cardColor,
          side: BorderSide(color: scheme.secondary, width: 2),
          textStyle: TextStyle(
            fontSize: AppTypeScale.md,
            fontWeight: FontWeight.w700,
            fontFamily: _bodyFontFamily,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          foregroundColor: scheme.secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        border: const OutlineInputBorder(borderRadius: AppRadius.cardRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: scheme.secondary.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: AppTypeScale.sm,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: scheme.secondary.withOpacity(0.5)),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        backgroundColor: scheme.secondary,
        contentTextStyle: TextStyle(
          color: scheme.onSecondary,
          fontSize: AppTypeScale.sm,
          fontWeight: FontWeight.w600,
          fontFamily: _bodyFontFamily,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.secondary.withOpacity(0.25),
        space: AppSpacing.lg,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0x44FF6D00),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
        iconColor: scheme.secondary,
        tileColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.xxl,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.xl,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.lg,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: AppTypeScale.lg,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontSize: AppTypeScale.sm,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: AppTypeScale.xs,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
    );
  }
}
