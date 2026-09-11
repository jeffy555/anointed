import 'package:anointed/features/kids_zone/games/animal_matching_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The board is laid out from the space actually available, so it must fit
/// without scrolling or overflowing on both a small and a large handset.
void main() {
  Widget harness(Widget child) {
    return ChangeNotifierProvider<TextToSpeechService>(
      create: (_) => TextToSpeechService(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  Widget game() {
    return AnimalMatchingGame(
      definition: kidsZoneGameForStop('ark_2')!,
      stopTitle: 'Level 2 — Two by Two',
      adventureTitle: 'Noah\'s Ark',
      onComplete: (_) {},
    );
  }

  // Physical pixels paired with the device pixel ratio that yields a realistic
  // logical size: 360x720 for the small phone, 480x1066 for the large one.
  for (final (String name, Size size, double dpr) in <(String, Size, double)>[
    ('small handset', Size(720, 1440), 2.0),
    ('large handset', Size(1440, 3200), 3.0),
  ]) {
    testWidgets('fits the board on a $name without scrolling',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(game()));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Twelve cards, all built — a lazy grid only builds what is visible, so
      // finding them all proves the whole board is on screen.
      expect(find.byType(GestureDetector), findsAtLeastNWidgets(12));

      final ScrollableState scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(
        scrollable.position.maxScrollExtent,
        0,
        reason: 'the board should not need scrolling',
      );
    });
  }

  testWidgets('deals six pairs drawn from the wider catalogue',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(game()));
    await tester.pump();

    // The HUD reports progress out of the pairs actually in play.
    expect(find.textContaining('of $kArkPairsPerGame'), findsOneWidget);
  });

  testWidgets('opens with four hearts, and practice mode retires them',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(game()));
    await tester.pump();

    // Four, not five: five hearts on twelve cards meant a child could brute
    // force the board without ever having to remember anything.
    expect(find.bySemanticsLabel('4 hearts left'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(4));

    // Practice mode is the escape hatch for a child who keeps running out —
    // the stop still completes, at one star.
    await tester.tap(find.byTooltip('Practice mode: unlimited hearts'));
    await tester.pump();
    expect(find.bySemanticsLabel('4 hearts left'), findsNothing);
    expect(find.byIcon(Icons.all_inclusive_rounded), findsWidgets);
  });
}
