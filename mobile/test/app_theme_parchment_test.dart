// The global Material theme used to be built from the arcade palette in
// AppColors (orange #FF6D00 / purple #7C4DFF) while every branded screen painted
// itself from ParchmentColors. The two met on the same screen: Settings got an
// orange app bar, and the Contact Us form got text fields whose label colours
// came from a surface that wasn't underneath them, reading as text colliding
// with the box edge. These tests pin the theme to the Parchment tokens so a
// future palette edit can't quietly reopen that seam.
import 'package:anointed/core/theme.dart';
import 'package:anointed/core/tokens.dart';
import 'package:anointed/features/map/parchment_codex_tokens.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/widgets/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('palette', () {
    test('surfaces and app bar come from the Parchment tokens', () {
      final ThemeData theme = AppTheme.light();

      expect(theme.colorScheme.surface, ParchmentColors.page);
      expect(theme.colorScheme.onSurface, ParchmentColors.ink);
      expect(theme.appBarTheme.backgroundColor, ParchmentColors.page);
      expect(theme.appBarTheme.foregroundColor, ParchmentColors.ink);
      expect(theme.cardTheme.color, ParchmentColors.cream);
    });

    test('dark mode resolves to the same parchment surface, not a dark one', () {
      // Parchment is a light surface and the branded screens hardcode it, so a
      // genuinely dark Material theme would only put dark widgets back on cream
      // paper. If someone reintroduces a dark variant, it has to be a designed
      // parchment-night palette -- not a silent revert to arcade purple.
      expect(AppTheme.dark().colorScheme.surface, ParchmentColors.page);
      expect(AppTheme.dark().colorScheme.onSurface, ParchmentColors.ink);
    });
  });

  group('input decoration', () {
    // Every slot in an InputDecoration that can paint text. A null colour here
    // means Material picks one from a surface that may not be the one the field
    // is sitting on -- which is exactly how the Contact Us form broke.
    final ThemeData theme = AppTheme.light();
    final InputDecorationTheme input = theme.inputDecorationTheme;

    final Map<String, TextStyle?> slots = <String, TextStyle?>{
      'labelStyle': input.labelStyle,
      'floatingLabelStyle': input.floatingLabelStyle,
      'hintStyle': input.hintStyle,
      'helperStyle': input.helperStyle,
      'errorStyle': input.errorStyle,
      'counterStyle': input.counterStyle,
    };

    slots.forEach((String name, TextStyle? style) {
      test('$name names its own colour and font', () {
        expect(style, isNotNull, reason: '$name was left to the Material default');
        expect(style!.color, isNotNull);
        expect(style.color!.opacity, greaterThan(0.3),
            reason: '$name would be too faint to read on parchment');
        expect(style.fontFamily, AnointedFonts.karla);
      });
    });

    test('the field fill is cream, so a floating label never lands on bare page',
        () {
      expect(input.filled, isTrue);
      expect(input.fillColor, ParchmentColors.cream);
    });
  });

  group('typography', () {
    // ThemeData.fontFamily is applied via TextTheme.apply, whose fontFamily
    // argument WINS over a style's own (TextStyle.apply does
    // `fontFamily ?? _fontFamily`). Setting it to Karla would therefore repaint
    // the Cormorant headings in Karla, app-wide and silently. theme.dart
    // deliberately omits it and names the family per style instead.
    final TextTheme text = AppTheme.light().textTheme;

    test('headings stay Cormorant', () {
      expect(text.displaySmall?.fontFamily, AnointedFonts.cormorantGaramond);
      expect(text.headlineMedium?.fontFamily, AnointedFonts.cormorantGaramond);
      expect(text.titleLarge?.fontFamily, AnointedFonts.cormorantGaramond);
    });

    test('body and label styles are Karla', () {
      expect(text.bodyLarge?.fontFamily, AnointedFonts.karla);
      expect(text.bodyMedium?.fontFamily, AnointedFonts.karla);
      expect(text.bodySmall?.fontFamily, AnointedFonts.karla);
      expect(text.labelLarge?.fontFamily, AnointedFonts.karla);
      expect(text.labelSmall?.fontFamily, AnointedFonts.karla);
    });

    test('no heading asks for a weight Cormorant does not ship', () {
      // The family declares 500/600/700 in pubspec.yaml; anything heavier gets
      // a synthesised approximation rather than a real face.
      for (final TextStyle? style in <TextStyle?>[
        text.displaySmall,
        text.headlineMedium,
        text.titleLarge,
      ]) {
        expect(style!.fontWeight!.index,
            lessThanOrEqualTo(FontWeight.w700.index));
      }
    });
  });

  group('Contact Us form shape', () {
    // The real arrangement from support_screen.dart: a category dropdown, a
    // 5-line message field carrying a 4000-char counter, and the reply-to email
    // field -- the three that were reported overlapping. 360dp is a common
    // narrow Android width; 2.4 is the app's own text-scale ceiling (see the
    // clamp in app.dart).
    for (final double scale in <double>[1.0, 1.25, 1.6, 2.4]) {
      testWidgets('renders without overflow at text scale $scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // isExpanded mirrors support_screen.dart. Dropped, the
                    // label is laid out at its intrinsic width beside the arrow
                    // in a spaceBetween Row with nothing able to shrink, and
                    // this overflows from text scale 1.25 up -- the reported
                    // "Contact Us is overlapped".
                    DropdownButtonFormField<String>(
                      value: 'general',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'general',
                          child: Text(
                            'Something else entirely',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (String? _) {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const TextField(
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        labelText: 'How can we help?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    EmailField(
                      controller: TextEditingController(),
                      label: 'Reply-to email',
                      required: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
