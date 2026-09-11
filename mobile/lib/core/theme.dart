import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/map/parchment_codex_tokens.dart';
import 'tokens.dart';

/// The app-wide Material theme, built from the Parchment Codex palette.
///
/// Every branded surface — the level map, profile, leaderboard, practice,
/// support, splash — paints itself from [ParchmentColors] directly, and those
/// screens are full of ordinary Material widgets (inputs, dialogs, app bars,
/// snackbars) that take their colours from here instead. While this theme was
/// built from the unrelated arcade palette in [AppColors], those two sets of
/// colours met on the same screen: white-and-purple text fields on cream paper,
/// an orange app bar over Settings. Deriving the theme from the same tokens the
/// screens use is what keeps the seam invisible.
///
/// Kids Zone is deliberately exempt — it paints from `KidsZoneColors` and reads
/// nothing from `Theme.of(context)`, so its brighter look survives all of this.
class AppTheme {
  const AppTheme._();

  static const String _displayFontFamily = AnointedFonts.cormorantGaramond;
  static const String _bodyFontFamily = AnointedFonts.karla;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: ColorScheme.light(
          // Ink-on-gold is the Parchment button treatment (see
          // ParchmentPrimaryButton), so ink is what `primary` has to mean for
          // an unstyled FilledButton to come out looking like the rest.
          primary: ParchmentColors.ink,
          onPrimary: ParchmentColors.goldLight,
          primaryContainer: ParchmentColors.goldPale,
          onPrimaryContainer: ParchmentColors.ink,
          secondary: ParchmentColors.gold,
          onSecondary: ParchmentColors.cream,
          secondaryContainer: ParchmentColors.creamDark,
          onSecondaryContainer: ParchmentColors.brown,
          tertiary: ParchmentColors.current,
          onTertiary: ParchmentColors.cream,
          tertiaryContainer: ParchmentColors.goldPale,
          onTertiaryContainer: ParchmentColors.currentShadow,
          surface: ParchmentColors.page,
          onSurface: ParchmentColors.ink,
          surfaceContainerHighest: ParchmentColors.creamDark,
          outline: ParchmentColors.inkBorder(0.25),
          error: _parchmentError,
          onError: ParchmentColors.cream,
        ),
        cardColor: ParchmentColors.cream,
        elevatedSurface: ParchmentColors.cream,
        secondaryText: ParchmentColors.inkMuted(0.6),
        systemOverlay: SystemUiOverlayStyle.dark,
      );

  /// Parchment is a light surface by definition, and the branded screens
  /// hardcode it, so a genuinely dark Material theme would only reintroduce the
  /// clash this class exists to remove. Dark mode therefore resolves to the
  /// same palette rather than to an arcade-purple one.
  static ThemeData dark() => light();

  static const Color _parchmentError = Color(0xFF9B3A3A);

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color cardColor,
    required Color elevatedSurface,
    required Color secondaryText,
    required SystemUiOverlayStyle systemOverlay,
  }) {
    final TextTheme text = _textTheme(scheme.onSurface, secondaryText);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      // Deliberately not ThemeData.fontFamily: it is applied to the text theme
      // with TextTheme.apply, whose fontFamily argument *wins* over a style's
      // own, which would repaint the Cormorant headings in Karla. Each style in
      // _textTheme names its family instead.
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: ParchmentColors.page,
        foregroundColor: ParchmentColors.ink,
        elevation: 0,
        shadowColor: ParchmentColors.inkBorder(0.2),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: ParchmentText.cormorant(size: 21),
        iconTheme: const IconThemeData(color: ParchmentColors.ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 12,
        shadowColor: ParchmentColors.inkBorder(0.25),
        indicatorColor: ParchmentColors.goldPale,
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
        indicatorColor: ParchmentColors.goldPale,
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
        // ParchmentCard draws a flat cream panel with a hairline ink border and
        // no shadow; a themed Card sitting beside one has to match it.
        elevation: 0,
        shadowColor: ParchmentColors.inkBorder(0.2),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: ParchmentColors.inkBorder(0.1)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(kMinTapTarget),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: AppTypeScale.md,
            fontWeight: FontWeight.w700,
            fontFamily: _bodyFontFamily,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTapTarget),
          foregroundColor: ParchmentColors.ink,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: ParchmentColors.inkBorder(0.25)),
          textStyle: const TextStyle(
            fontSize: AppTypeScale.md,
            fontWeight: FontWeight.w600,
            fontFamily: _bodyFontFamily,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          foregroundColor: ParchmentColors.brown,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: _bodyFontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        // A floating label sits *in* the notch it cuts in the outline, so it
        // paints over both the field fill and the page behind it. Left at the
        // Material default it inherited a colour meant for a different surface
        // and read as text colliding with the box edge — the Contact Us form
        // was the worst case, three stacked fields all doing it. Every slot
        // that can render text here is given an explicit ink/muted colour so
        // none of them can fall back again.
        labelStyle: ParchmentText.karla(
          size: AppTypeScale.md,
          color: ParchmentColors.inkMuted(0.75),
        ),
        floatingLabelStyle: ParchmentText.karla(
          size: AppTypeScale.sm,
          weight: FontWeight.w700,
          color: ParchmentColors.brown,
        ),
        hintStyle: ParchmentText.karla(
          size: AppTypeScale.md,
          color: ParchmentColors.inkMuted(0.45),
        ),
        helperStyle: ParchmentText.karla(
          size: AppTypeScale.xs,
          color: ParchmentColors.inkMuted(0.6),
        ),
        errorStyle: ParchmentText.karla(
          size: AppTypeScale.xs,
          weight: FontWeight.w600,
          color: _parchmentError,
        ),
        counterStyle: ParchmentText.karla(
          size: AppTypeScale.xs,
          color: ParchmentColors.inkMuted(0.5),
        ),
        prefixStyle: ParchmentText.karla(size: AppTypeScale.md),
        suffixStyle: ParchmentText.karla(size: AppTypeScale.md),
        iconColor: ParchmentColors.brown,
        prefixIconColor: ParchmentColors.brown,
        suffixIconColor: ParchmentColors.brown,
        border: const OutlineInputBorder(borderRadius: AppRadius.cardRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: ParchmentColors.inkBorder(0.18)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: ParchmentColors.gold, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: _parchmentError),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: _parchmentError, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardRadius,
          borderSide: BorderSide(color: ParchmentColors.inkBorder(0.08)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ParchmentColors.creamDark,
        labelStyle: ParchmentText.karla(
          size: AppTypeScale.sm,
          weight: FontWeight.w700,
          color: ParchmentColors.ink,
        ),
        side: BorderSide(color: ParchmentColors.gold.withOpacity(0.35)),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: ParchmentText.cormorant(size: 20),
        contentTextStyle: ParchmentText.karla(
          size: AppTypeScale.md,
          height: 1.4,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        textStyle: ParchmentText.karla(size: AppTypeScale.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      // The category dropdown on Contact Us opens one of these; left unstyled
      // it popped a default-surface menu over the parchment page.
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: ParchmentText.karla(size: AppTypeScale.md),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(cardColor),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        backgroundColor: ParchmentColors.ink,
        actionTextColor: ParchmentColors.goldLight,
        contentTextStyle: ParchmentText.karla(
          size: AppTypeScale.sm,
          weight: FontWeight.w600,
          color: ParchmentColors.cream,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ParchmentColors.inkBorder(0.12),
        space: AppSpacing.lg,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ParchmentColors.gold,
        linearTrackColor: ParchmentColors.creamDark,
        circularTrackColor: ParchmentColors.inkBorder(0.08),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
        iconColor: ParchmentColors.brown,
        textColor: ParchmentColors.ink,
        titleTextStyle: ParchmentText.karla(
          size: AppTypeScale.md,
          weight: FontWeight.w600,
        ),
        subtitleTextStyle: ParchmentText.karla(
          size: AppTypeScale.sm,
          color: ParchmentColors.inkMuted(0.65),
          height: 1.35,
        ),
        tileColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? ParchmentColors.goldLight
              : ParchmentColors.cream,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? ParchmentColors.ink
              : ParchmentColors.creamDark,
        ),
        trackOutlineColor: WidgetStatePropertyAll<Color>(
          ParchmentColors.inkBorder(0.2),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? ParchmentColors.ink
              : ParchmentColors.inkMuted(0.4),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? ParchmentColors.ink
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll<Color>(
          ParchmentColors.goldLight,
        ),
        side: BorderSide(color: ParchmentColors.inkBorder(0.35), width: 1.5),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      // w700 rather than w800: CormorantGaramond only ships 500/600/700, and
      // asking for a weight it does not have gets a synthesised approximation.
      displaySmall: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.xxl,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.xl,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: _displayFontFamily,
        fontSize: AppTypeScale.lg,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.lg,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.sm,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.xs,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: _bodyFontFamily,
        fontSize: AppTypeScale.md,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
    );
  }
}
