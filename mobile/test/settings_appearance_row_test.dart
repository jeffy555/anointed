// The Appearance row (theme ListTile + trailing SegmentedButton) was reported
// rendering with "Appearance" and "Match device" wrapped one letter per line —
// a `ListTile.trailing` squeezed to near-zero width once its sibling
// SegmentedButton claims the row. Unlike the Kids Zone layout sweep earlier this
// session, SettingsScreen was never covered by a layout test at any scale.
import 'package:anointed/core/local_store.dart';
import 'package:anointed/features/profile/settings_screen.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(
      await SharedPreferences.getInstance(),
      const FlutterSecureStorage(),
    );
  });

  Widget harness(double scale, {required Size size}) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(store),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            size: size,
          ),
          child: child!,
        ),
        home: const _SettingsHostForTest(),
      ),
    );
  }

  // 360x800 is a common narrow Android width (close to the A069P report);
  // 1.0 is the row as most users see it; 1.25 is the in-app "Large text"
  // toggle alone; 1.6 and 2.4 are combined OS+in-app scale, the latter being
  // the app's own documented ceiling (see the textScaler clamp in app.dart).
  for (final double scale in <double>[1.0, 1.25, 1.6, 2.0, 2.4]) {
    testWidgets('Appearance row at scale $scale on a 360dp phone',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(scale, size: const Size(360, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Appearance row overflowed/broke at text scale $scale');
    });
  }
}

/// Mounts the real `AppearanceRow` from settings_screen.dart in isolation,
/// sidestepping the full screen's provider-heavy dependencies (accounts,
/// notifications, session) that this row never touches — so the fix under
/// test is the fix that ships, not a copy that could quietly drift from it.
class _SettingsHostForTest extends StatelessWidget {
  const _SettingsHostForTest();

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    return Scaffold(
      body: AppearanceRow(
        themeMode: settings.themeMode,
        onThemeModeChanged: settings.setThemeMode,
      ),
    );
  }
}
