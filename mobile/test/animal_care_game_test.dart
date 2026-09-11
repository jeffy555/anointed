import 'package:anointed/core/local_store.dart';
import 'package:anointed/features/kids_zone/games/animal_care_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animal Care teaches its icon-to-tool mapping before the first round, and
/// never puts a child on a clock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  Future<void> newStore() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(
      await SharedPreferences.getInstance(),
      const FlutterSecureStorage(),
    );
  }

  Widget harness() {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<LocalStore>.value(value: store),
        // The shared game shell resolves TTS from Provider for its read-aloud
        // button.
        ChangeNotifierProvider<TextToSpeechService>(
          create: (_) => TextToSpeechService(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimalCareGame(
          definition: kidsZoneGameForStop('ark_3')!,
          stopTitle: 'Level 3 — Animal Care',
          adventureTitle: "Noah's Ark",
          onComplete: (_) {},
        ),
      ),
    );
  }

  /// Advances the game's Ticker. A single long `pump` only produces one frame,
  /// which the tick loop clamps to 50ms — far too little to see round changes.
  Future<void> run(WidgetTester tester, double seconds) async {
    for (int i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void sizeAsHandset(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('first play teaches the tool mapping and waits for the child',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await newStore();

    await tester.pumpWidget(harness());
    await tester.pump();

    // Every need is paired with the tool that answers it, so the child is not
    // asked to guess.
    expect(find.text('How to help the animals'), findsOneWidget);
    for (final String tool in <String>['Feed', 'Water', 'Clean', 'Comfort']) {
      expect(find.text(tool), findsWidgets, reason: '$tool must be taught');
    }

    // The card is held open, not dismissed by a timer: ten seconds later the
    // round still has not begun.
    await run(tester, 10);
    expect(find.text('How to help the animals'), findsOneWidget);

    await tester.tap(find.text("I'm ready!"));
    await tester.pump();
    expect(find.text('How to help the animals'), findsNothing);
  });

  testWidgets('the card is not shown again on a later play, but the help '
      'button brings it back', (WidgetTester tester) async {
    sizeAsHandset(tester);
    await newStore();
    await store.markKidsZoneTutorialSeen('ark_animal_care');

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('How to help the animals'), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pump();
    expect(find.text('How to help the animals'), findsOneWidget);
  });

  testWidgets('a waiting animal is never given up on', (WidgetTester tester) async {
    sizeAsHandset(tester);
    await newStore();
    await store.markKidsZoneTutorialSeen('ark_animal_care');

    await tester.pumpWidget(harness());
    await tester.pump();

    // Play well past the point where a countdown would have expired the need.
    await run(tester, 40);

    // Needs decay into sadness rather than expiring, so the meter bottoms out
    // and stays there. An expiring-need design would clear the neglected needs
    // and let the meter climb back up; a countdown design would have ended the
    // round long before now.
    expect(find.bySemanticsLabel('Animals are 0% happy'), findsOneWidget);
    expect(find.textContaining('Cared for 0 of'), findsOneWidget);
  });
}
