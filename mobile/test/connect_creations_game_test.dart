import 'package:anointed/features/kids_zone/games/connect_creations_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level 2 lays both columns on one shared row height. That is what keeps the
/// day and creation cards aligned across the gap, keeps the connecting wires
/// anchored to real cards, and stops a long label from overflowing the board.
void main() {
  Widget harness() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ConnectCreationsGame(
        definition: kidsZoneGameForStop('garden_2')!,
        stopTitle: 'Level 2 — Connect Creations',
        adventureTitle: 'Creation Garden',
        onComplete: (_) {},
      ),
    );
  }

  // 360x720 and 360x640 logical — the short one is where the old fixed-height
  // rows overflowed.
  for (final (String name, Size size) in <(String, Size)>[
    ('a standard handset', Size(720, 1440)),
    ('a short handset', Size(720, 1280)),
  ]) {
    testWidgets('lays out without overflowing on $name',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every day and every creation is on screen at once',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();

    final List<DayCreationPair> pairs =
        kidsZoneGameForStop('garden_2')!.dayCreations;

    for (final DayCreationPair pair in pairs) {
      expect(
        find.text(pair.dayLabel),
        findsOneWidget,
        reason: '${pair.dayLabel} is missing from the board',
      );
      expect(
        find.text(pair.creationLabel),
        findsOneWidget,
        reason: '${pair.creationLabel} is missing from the board',
      );
    }
  });

  testWidgets('mixes in creations that belong to no day',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();

    final KidsZoneGameDefinition def = kidsZoneGameForStop('garden_2')!;
    expect(def.creationDistractors, isNotEmpty);

    // Distractors sit in the creation column but have no day to match.
    for (final DayCreationPair d in def.creationDistractors) {
      expect(
        find.text(d.creationLabel),
        findsOneWidget,
        reason: '${d.creationLabel} should be offered as a wrong answer',
      );
      expect(
        def.dayCreations.any((DayCreationPair p) => p.dayId == d.dayId),
        isFalse,
        reason: '${d.creationLabel} must not be connectable to any day',
      );
    }
  });

  test('distractor ids never collide with a real day', () {
    final KidsZoneGameDefinition def = kidsZoneGameForStop('garden_2')!;
    final Set<String> dayIds =
        def.dayCreations.map((DayCreationPair p) => p.dayId).toSet();

    for (final DayCreationPair d in def.creationDistractors) {
      expect(dayIds.contains(d.dayId), isFalse);
    }
    // Labels must be distinct too, or two cards would look identical.
    final List<String> labels = <String>[
      for (final DayCreationPair p in <DayCreationPair>[
        ...def.dayCreations,
        ...def.creationDistractors,
      ])
        p.creationLabel,
    ];
    expect(labels.toSet().length, labels.length);
  });

  test('each day carries its own wire colour', () {
    // The finished board doubles as a colour summary of the week, so no two
    // days may share a line colour.
    final List<DayCreationPair> days =
        kidsZoneGameForStop('garden_2')!.dayCreations;
    final Set<int> colours =
        days.map((DayCreationPair d) => d.color.value).toSet();
    expect(colours.length, days.length);
  });

  testWidgets('day rows and creation rows share the same vertical centres',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();

    final List<DayCreationPair> pairs =
        kidsZoneGameForStop('garden_2')!.dayCreations;

    // The creation column is longer than the day column now that distractors
    // are mixed in, so the invariant is that both sit on the SAME row grid:
    // every day row must line up with some creation row.
    final List<double> creationCentres = <double>[
      for (final DayCreationPair p in <DayCreationPair>[
        ...pairs,
        ...kidsZoneGameForStop('garden_2')!.creationDistractors,
      ])
        tester.getCenter(find.text(p.creationLabel)).dy,
    ];

    for (final DayCreationPair p in pairs) {
      final double dayCentre = tester.getCenter(find.text(p.dayLabel)).dy;
      expect(
        creationCentres.any((double c) => (c - dayCentre).abs() < 1.0),
        isTrue,
        reason: '${p.dayLabel} does not sit level with any creation row',
      );
    }
  });

  testWidgets('tapping a day then a creation draws a connection',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text('Day 1'));
    await tester.pump();
    await tester.tap(find.text('Light'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
