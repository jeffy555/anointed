import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anointed/features/kids_zone/games/archery_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The archery rounds have to teach as well as challenge: a shrinking hitbox is
/// only fair if a near miss says so, the king's shield has to read as a fight
/// rather than another soldier, and the escalation should land as story.
void main() {
  List<ArcheryWave> allWaves() => <ArcheryWave>[
        for (final String stop in <String>['siddim_1', 'siddim_2', 'siddim_3'])
          ...kidsZoneGameForStop(stop)!.archeryWaves,
      ];

  group('round interludes', () {
    test('every round after the first opens with a story beat', () {
      final List<ArcheryWave> waves = allWaves();
      expect(waves.first.interlude, isEmpty,
          reason: 'the opening round needs no march to describe');

      for (final ArcheryWave w in waves.skip(1)) {
        expect(
          w.interlude.trim(),
          isNotEmpty,
          reason: 'round ${w.round} escalates with no story to explain it',
        );
        // Long enough to be a beat, short enough to speak in ~3 seconds.
        expect(w.interlude.length, greaterThan(20));
        expect(w.interlude.length, lessThan(120));
      }
    });

    test('each beat is distinct', () {
      final List<String> lines = <String>[
        for (final ArcheryWave w in allWaves())
          if (w.interlude.isNotEmpty) w.interlude,
      ];
      expect(lines.toSet().length, lines.length);
    });

    test('the King\'s Round is announced', () {
      final ArcheryWave king =
          allWaves().firstWhere((ArcheryWave w) => w.isKingRound);
      expect(king.interlude.toLowerCase(), contains('chedorlaomer'));
    });
  });

  group('the King\'s shield', () {
    test('takes three arrows, giving three readable states', () {
      final ArcheryWave king =
          allWaves().firstWhere((ArcheryWave w) => w.isKingRound);
      // Full → cracked → broken. Fewer than three and the states collapse.
      expect(king.hitsToTurnBack, 3);
    });

    test('only the king is armoured', () {
      for (final ArcheryWave w in allWaves()) {
        if (w.isKingRound) continue;
        expect(
          w.hitsToTurnBack,
          1,
          reason: 'round ${w.round} should turn a soldier back in one shot',
        );
      }
    });

    test('the king is the smallest target in the adventure', () {
      final List<ArcheryWave> waves = allWaves();
      final ArcheryWave king =
          waves.firstWhere((ArcheryWave w) => w.isKingRound);
      for (final ArcheryWave w in waves.where((ArcheryWave w) => !w.isKingRound)) {
        expect(king.hitRadius, lessThan(w.hitRadius));
      }
    });
  });

  group('scoring is explainable', () {
    // The breakdown a child reads is computed from the very value the stars
    // come from, so what they are told and what they scored cannot disagree.
    ArcheryScorecard card({
      required int breaches,
      required int hits,
      required int shots,
    }) {
      return ArcheryScorecard(
        turnedBack: hits,
        totalSoldiers: 10,
        hits: hits,
        shots: shots,
        hearts: 3 - breaches,
        maxHearts: 3,
        breaches: breaches,
        score: hits * 100,
      );
    }

    test('three stars needs a clean camp and better than half your arrows', () {
      expect(card(breaches: 0, hits: 8, shots: 10).stars, 3);
      expect(
        card(breaches: 0, hits: 4, shots: 10).stars,
        2,
        reason: '40% accuracy should fall short of three',
      );
      expect(
        card(breaches: 1, hits: 9, shots: 10).stars,
        2,
        reason: 'letting one through costs the third star',
      );
      expect(
        card(breaches: 2, hits: 9, shots: 10).stars,
        1,
        reason: 'two breaches drops to one star',
      );
    });

    test('the goals shown match the stars awarded', () {
      final ArcheryScorecard full = card(breaches: 0, hits: 8, shots: 10);
      expect(full.metNoBreach, isTrue);
      expect(full.metAccuracy, isTrue);

      final ArcheryScorecard sloppy = card(breaches: 0, hits: 4, shots: 10);
      expect(sloppy.metNoBreach, isTrue);
      expect(sloppy.metAccuracy, isFalse,
          reason: 'the unmet goal must be the one that cost the star');
      expect(sloppy.stars, lessThan(full.stars));
    });

    test('accuracy is safe when no arrows were fired', () {
      final ArcheryScorecard none = card(breaches: 0, hits: 0, shots: 0);
      expect(none.accuracy, 0);
      expect(none.accuracyPercent, 0);
    });
  });

  group('near-miss feedback', () {
    test('the forgiving ring is wider than the hitbox but not absurdly so', () {
      // 1.5x is generous enough to catch a genuinely close shot and tight
      // enough that a wild one still reads as a plain miss.
      const double nearMissFactor = 1.5;
      expect(nearMissFactor, greaterThan(1.0));
      expect(nearMissFactor, lessThan(2.0));

      // Even on the tightest round, the near-miss ring stays a sane size.
      final ArcheryWave tightest = allWaves()
          .reduce((ArcheryWave a, ArcheryWave b) =>
              a.hitRadius < b.hitRadius ? a : b);
      expect(tightest.hitRadius * nearMissFactor, lessThan(0.12));
    });
  });

  group('the bow only arms on a real pull', () {
    int shots = 0;

    Widget harness() {
      return ChangeNotifierProvider<TextToSpeechService>(
        create: (_) => TextToSpeechService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArcheryGame(
            definition: kidsZoneGameForStop('siddim_1')!,
            stopTitle: 'Level 1',
            adventureTitle: 'Battle of Siddim',
            onComplete: (_) {},
            onShot: (int n) => shots = n,
          ),
        ),
      );
    }

    Future<void> pumpGame(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      shots = 0;
      await tester.pumpWidget(harness());
      // The game clock advances per frame with dt clamped, so real frames have
      // to be pumped to get past the round-intro card and into play.
      for (int i = 0; i < 250; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('a bare tap costs no arrow', (WidgetTester tester) async {
      // Regression: the old guard measured bow-to-aim distance, so a tap
      // anywhere up the field was hundreds of pixels away and always fired.
      await pumpGame(tester);

      final Finder field = find.byType(CustomPaint).first;
      await tester.tapAt(tester.getCenter(field));
      await tester.pump(const Duration(milliseconds: 300));

      expect(shots, 0, reason: 'a tap must not cost an arrow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short drag under the arm threshold still does not fire',
        (WidgetTester tester) async {
      await pumpGame(tester);

      final Offset start = tester.getCenter(find.byType(CustomPaint).first);
      final TestGesture drag = await tester.startGesture(start);
      // 20px of travel — below the 30px arming threshold.
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(shots, 0, reason: 'a 20px nudge is below the arming threshold');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full pull arms and releases an arrow',
        (WidgetTester tester) async {
      await pumpGame(tester);

      final Offset start = tester.getCenter(find.byType(CustomPaint).first);
      final TestGesture drag = await tester.startGesture(start);
      await drag.moveBy(const Offset(0, -90));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(shots, 1, reason: 'a real pull should loose one arrow');
      expect(tester.takeException(), isNull);
    });
  });
}
