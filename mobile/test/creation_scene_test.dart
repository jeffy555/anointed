import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/features/kids_zone/widgets/creation_world_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Creation backdrop paints itself from the day number, so the story and
/// the picture cannot drift apart.
void main() {
  test('the intro walks day 0 through day 7 in order', () {
    final List<CreationDayIntro> days =
        kidsZoneGameForStop('creation_intro')!.introDays;

    expect(days.length, 8);
    for (int i = 0; i < days.length; i++) {
      expect(days[i].day, i, reason: 'scene ${days[i].dayLabel} is out of step');
      expect(days[i].narration.trim(), isNotEmpty);
    }
    // Day 0 is the formless dark before light — its own scene, not Day 1's.
    expect(days.first.dayLabel, 'Before Day One');
    expect(days.last.day, 7);
  });

  testWidgets('renders every day of the week without error',
      (WidgetTester tester) async {
    for (int day = 0; day <= 7; day++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 220,
              child: CreationWorldView(day: day),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'day $day failed to paint');
    }
  });

  testWidgets('animates when the day advances', (WidgetTester tester) async {
    Widget at(int day) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 220,
              child: CreationWorldView(day: day),
            ),
          ),
        );

    await tester.pumpWidget(at(0));
    await tester.pump(const Duration(seconds: 2));

    // Moving to Day 1 restarts the reveal, so a frame is scheduled.
    await tester.pumpWidget(at(1));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('fish swim in water, not on the meadow', () {
    // Regression: the land used to fill the frame to the bottom, hiding the sea
    // entirely, so the Day 5 fish were drawn on top of the grass.
    const double swimTop = CreationSceneLayout.fishBand - 0.030;
    const double swimBottom = CreationSceneLayout.fishBand + 0.030;

    expect(
      swimTop,
      greaterThan(CreationSceneLayout.horizon),
      reason: 'fish must stay below the horizon, in the water',
    );
    expect(
      swimBottom,
      lessThan(CreationSceneLayout.shore),
      reason: 'fish must stay above the shore, out of the meadow',
    );
  });

  test('there is a visible band of sea between horizon and shore', () {
    expect(CreationSceneLayout.horizon, lessThan(CreationSceneLayout.shore));
    expect(
      CreationSceneLayout.shore - CreationSceneLayout.horizon,
      greaterThan(0.10),
      reason: 'the sea band must be wide enough to read as water',
    );
    // Land needs room in the foreground for trees, animals and people.
    expect(1.0 - CreationSceneLayout.shore, greaterThan(0.2));
  });

  testWidgets('the sabbath quiets the world instead of adding to it',
      (WidgetTester tester) async {
    // Day 7's distinctive is stillness: the drifting, flapping and twinkling
    // all but stop, so the scene must keep repainting (the rest glow breathes)
    // while the world itself settles.
    Widget at(int day) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 220,
              child: CreationWorldView(day: day),
            ),
          ),
        );

    await tester.pumpWidget(at(6));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(at(7));
    // Let the reveal finish so rest is fully settled.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    // Still animating — the sabbath breath replaces the day's activity rather
    // than freezing the scene outright.
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('day 7 reads as dusk, not another bright working day', () {
    // A guard on the palette rather than the pixels: rest should be visibly
    // dimmer than the days of work that precede it.
    double luminanceOf(int day) {
      final List<Color> sky = creationSkyFor(day);
      return sky
              .map((Color c) => c.computeLuminance())
              .reduce((double a, double b) => a + b) /
          sky.length;
    }

    for (int day = 2; day <= 6; day++) {
      expect(
        luminanceOf(7),
        lessThan(luminanceOf(day)),
        reason: 'day 7 should be dimmer than day $day',
      );
    }
    // But still far brighter than the void it started from.
    expect(luminanceOf(7), greaterThan(luminanceOf(0)));
  });

  testWidgets('the rainbow finish still paints', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: CreationWorldView(day: 7, showRainbow: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
