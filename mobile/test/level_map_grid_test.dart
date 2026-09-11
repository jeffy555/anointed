import 'package:anointed/features/map/level_map_progress.dart';
import 'package:anointed/features/map/parchment_codex_widgets.dart';
import 'package:anointed/models/level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The journey is one continuous run of levels — no book/chapter grouping — and
/// every tile answers a tap, including locked ones (which open the unlock
/// offer rather than silently doing nothing).
void main() {
  List<LevelSummary> buildLevels(int count, {int freeThrough = 5}) {
    return <LevelSummary>[
      for (int i = 1; i <= count; i++)
        LevelSummary(
          levelNumber: i,
          title: 'Level $i',
          difficultyTier: DifficultyTier.easy,
          timerSeconds: 30,
          isFreeTier: i <= freeThrough,
          locked: i > freeThrough,
          completed: i < 3,
          bestScore: i < 3 ? 100 : null,
          isCurrent: i == 3,
          playable: true,
          availableVariantTypes: const <VariantType>[],
        ),
    ];
  }

  Widget harness({
    required List<LevelSummary> levels,
    required ValueChanged<LevelSummary> onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ParchmentLevelGrid(
            levels: levels,
            progress: const LevelMapProgress(
              currentLevel: 3,
              unlockedThrough: 5,
              totalLevels: 100,
            ),
            onLevelTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('shows every level in one grid, with no chapter headings',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(levels: buildLevels(100), onTap: (_) {}));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ParchmentLevelNode), findsNWidgets(100));

    // Chapter mode is gone: none of the old book headings should appear.
    for (final String heading in <String>[
      'Genesis',
      'Exodus',
      'Psalms',
      'Prophets',
      'Gospels',
      'CHAPTER I',
    ]) {
      expect(find.text(heading), findsNothing, reason: '$heading still shown');
    }
  });

  testWidgets('an unlocked level reports its tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    LevelSummary? tapped;
    await tester.pumpWidget(
      harness(levels: buildLevels(10), onTap: (LevelSummary l) => tapped = l),
    );
    await tester.pump();

    await tester.tap(find.byType(ParchmentLevelNode).at(2));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.levelNumber, 3);
  });

  testWidgets('a locked level still reports its tap, so the unlock can show',
      (WidgetTester tester) async {
    // Regression: locked tiles used to pass null to InkWell.onTap, so the
    // paywall the map screen wires up could never be reached.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    LevelSummary? tapped;
    await tester.pumpWidget(
      harness(
        levels: buildLevels(10, freeThrough: 5),
        onTap: (LevelSummary l) => tapped = l,
      ),
    );
    await tester.pump();

    // Level 9 sits beyond the free tier, so it is locked.
    await tester.tap(find.byType(ParchmentLevelNode).at(8));
    await tester.pump();

    expect(tapped, isNotNull, reason: 'locked tile swallowed the tap');
    expect(tapped!.levelNumber, 9);
    expect(tapped!.locked, isTrue);
  });
}
