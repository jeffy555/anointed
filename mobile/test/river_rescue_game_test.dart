import 'package:anointed/features/kids_zone/games/river_rescue_game.dart';
import 'package:anointed/features/kids_zone/widgets/moses_scene_view.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// River Rescue is the only Kids Zone game that will not wait for the child to
/// think, so its fairness has to be a property of the data rather than of how
/// carefully it was played. These tests re-derive that from the shipped
/// timelines: a tuning pass that introduces a trap fails here, not on a phone.
void main() {
  final List<RiverStage> stages = kidsZoneGameForStop('moses_1')!.riverStages;

  // Matches the game's own feel constants. A cluster is a wall of hazards close
  // enough together that the child meets them as one decision.
  const double clusterWindow = 2.5;
  const double laneSwitchSeconds = 0.18;
  const double reactionSeconds = 0.30;

  /// Hazards grouped into the walls the child actually experiences.
  List<({double distance, Set<RiverLane> free})> clustersOf(RiverStage stage) {
    final List<RiverSpawn> sorted = stage.obstacles.toList()
      ..sort((RiverSpawn a, RiverSpawn b) => a.distance.compareTo(b.distance));

    final List<({double distance, Set<RiverLane> free})> out =
        <({double distance, Set<RiverLane> free})>[];
    int i = 0;
    while (i < sorted.length) {
      final double start = sorted[i].distance;
      final Set<RiverLane> blocked = <RiverLane>{};
      while (i < sorted.length && sorted[i].distance - start < clusterWindow) {
        blocked.add(sorted[i].lane);
        i++;
      }
      out.add((
        distance: start,
        free: RiverLane.values.toSet().difference(blocked),
      ));
    }
    return out;
  }

  group('stage data is fair by construction', () {
    for (final RiverStage stage in stages) {
      test('${stage.id} always leaves a clear lane', () {
        for (final ({double distance, Set<RiverLane> free}) c
            in clustersOf(stage)) {
          expect(
            c.free,
            isNotEmpty,
            reason: 'all three lanes are blocked at ${c.distance}m in '
                '${stage.id} — the basket would have nowhere to go',
          );
        }
      });

      test('${stage.id} can be steered end to end without hopping or ducking',
          () {
        // The strongest form of the "always an escape" rule: a child who never
        // works out the vertical moves can still finish, because every hop and
        // duck hazard has a lane-switch alternative in reach. Reachability is
        // computed over fully clear lanes only, at the stage's fastest speed.
        final List<({double distance, Set<RiverLane> free})> clusters =
            clustersOf(stage);
        if (clusters.isEmpty) return;

        Set<RiverLane> reachable = clusters.first.free;
        for (int i = 1; i < clusters.length; i++) {
          final double gap = clusters[i].distance - clusters[i - 1].distance;
          final double seconds = gap / stage.endSpeed;
          final int steps =
              ((seconds - reactionSeconds) / laneSwitchSeconds).floor();

          final Set<RiverLane> spread = <RiverLane>{};
          for (final RiverLane from in reachable) {
            for (final RiverLane to in RiverLane.values) {
              if ((to.index - from.index).abs() <= steps) spread.add(to);
            }
          }
          reachable = spread.intersection(clusters[i].free);
          expect(
            reachable,
            isNotEmpty,
            reason: 'no lane path through ${stage.id} at '
                '${clusters[i].distance}m — the wall before it forces the '
                'basket into a lane it cannot leave in time',
          );
        }
      });

      test('${stage.id} never asks a child to hop or duck a crocodile', () {
        for (final RiverSpawn s in stage.obstacles) {
          if (s.kind != RiverObstacleKind.sleepyCrocodile) continue;
          expect(s.kind.response, RiverResponse.switchLane);
        }
      });

      test('${stage.id} puts no lotus where a hazard stands', () {
        // A flower inside a wall would teach the child that collecting and
        // surviving are opposites, which is not the bargain this game makes.
        for (final RiverLotus lotus in stage.lotuses) {
          for (final RiverSpawn s in stage.obstacles) {
            if (s.lane != lotus.lane) continue;
            expect(
              (s.distance - lotus.distance).abs(),
              greaterThan(clusterWindow),
              reason: 'lotus at ${lotus.distance}m sits on a '
                  '${s.kind.name} in ${stage.id}',
            );
          }
        }
      });
    }

    test('a crocodile never shares a wall with another crocodile', () {
      for (final RiverStage stage in stages) {
        for (final ({double distance, Set<RiverLane> free}) c
            in clustersOf(stage)) {
          final int crocs = stage.obstacles
              .where((RiverSpawn s) =>
                  s.kind == RiverObstacleKind.sleepyCrocodile &&
                  (s.distance - c.distance).abs() < clusterWindow)
              .length;
          expect(crocs, lessThanOrEqualTo(1));
        }
      }
    });
  });

  group('every obstacle kind states one unambiguous answer', () {
    test('reeds and crocodiles are steered around; logs and vines are not', () {
      expect(RiverObstacleKind.reedCluster.response, RiverResponse.switchLane);
      expect(
          RiverObstacleKind.sleepyCrocodile.response, RiverResponse.switchLane);
      expect(RiverObstacleKind.floatingLog.response, RiverResponse.hop);
      expect(RiverObstacleKind.reedVine.response, RiverResponse.duck);
    });

    test('the vine hangs high and the log floats low', () {
      expect(RiverObstacleKind.reedVine.isOverhead, isTrue);
      expect(RiverObstacleKind.floatingLog.isLow, isTrue);
      expect(RiverObstacleKind.sleepyCrocodile.isOverhead, isFalse);
      expect(RiverObstacleKind.sleepyCrocodile.isLow, isFalse);
    });
  });

  group('difficulty escalates strictly', () {
    test('each stage is longer and faster than the one before', () {
      // Compared start-to-start and end-to-end, not end-to-start: a new stage
      // deliberately opens below the speed the last one closed at, so the
      // child gets a moment to settle before the ramp climbs past it again.
      for (int i = 1; i < stages.length; i++) {
        expect(stages[i].length, greaterThan(stages[i - 1].length));
        expect(stages[i].startSpeed, greaterThan(stages[i - 1].startSpeed));
        expect(stages[i].endSpeed, greaterThan(stages[i - 1].endSpeed));
      }
    });

    test('a stage never opens faster than it closes', () {
      for (final RiverStage s in stages) {
        expect(s.endSpeed, greaterThan(s.startSpeed));
      }
    });

    test('stage 3 runs 40% faster than stage 1 opens', () {
      expect(
          stages.last.startSpeed, closeTo(stages.first.startSpeed * 1.4, 0.01));
    });

    test('hazards get denser', () {
      double density(RiverStage s) => s.obstacles.length / s.length;
      for (int i = 1; i < stages.length; i++) {
        expect(density(stages[i]), greaterThan(density(stages[i - 1])));
      }
    });

    test('speed ramps within a stage rather than jumping', () {
      for (final RiverStage s in stages) {
        expect(s.speedAt(0), s.startSpeed);
        expect(s.speedAt(s.length), s.endSpeed);
        expect(s.speedAt(s.length / 2),
            closeTo((s.startSpeed + s.endSpeed) / 2, 0.001));
      }
    });

    test('each stage lands in its intended play time', () {
      // Deliberately brisk — a child should meet the crocodile (stage 3,
      // obstacle-gated) around 40 seconds in, not 90. The whole run is well
      // under two minutes, which is what makes it read as a runner rather
      // than a slow float.
      expect(stages[0].approximateSeconds, inInclusiveRange(16, 20));
      expect(stages[1].approximateSeconds, inInclusiveRange(22, 27));
      expect(stages[2].approximateSeconds, inInclusiveRange(28, 33));
    });

    test('new hazard kinds are introduced one stage at a time', () {
      Set<RiverObstacleKind> kinds(RiverStage s) =>
          s.obstacles.map((RiverSpawn o) => o.kind).toSet();

      expect(kinds(stages[0]), <RiverObstacleKind>{
        RiverObstacleKind.reedCluster,
      });
      // Logs arrive with the stage whose cue teaches hopping.
      expect(kinds(stages[1]), contains(RiverObstacleKind.floatingLog));
      expect(
          kinds(stages[1]), isNot(contains(RiverObstacleKind.sleepyCrocodile)));
      expect(kinds(stages[1]), isNot(contains(RiverObstacleKind.reedVine)));
      expect(
          kinds(stages[2]),
          containsAll(<RiverObstacleKind>[
            RiverObstacleKind.reedVine,
            RiverObstacleKind.sleepyCrocodile,
          ]));
    });

    test('blessings arrive generously relative to how long a stage runs', () {
      // Compressing the stages for pace compresses this cadence too — a
      // blessing every ten-odd seconds on an 18-second stage is the same
      // generosity as one every 20-25s was on the original, much longer run.
      for (final RiverStage s in stages) {
        expect(s.blessings, isNotEmpty);
        final double perBlessing = s.approximateSeconds / s.blessings.length;
        expect(perBlessing, inInclusiveRange(10, 32),
            reason: '${s.id} hands out a blessing every '
                '${perBlessing.toStringAsFixed(0)}s');
      }
    });
  });

  group('riverRescueStars', () {
    test('three stars need full hearts and 80% of the flowers', () {
      expect(
        riverRescueStars(
            heartsRemaining: 3, lotusCollected: 80, lotusAvailable: 100),
        3,
      );
      // Exactly on the boundary counts.
      expect(
        riverRescueStars(
            heartsRemaining: 3, lotusCollected: 79, lotusAvailable: 100),
        2,
      );
      expect(
        riverRescueStars(
            heartsRemaining: 2, lotusCollected: 100, lotusAvailable: 100),
        2,
      );
    });

    test('two stars need two hearts and half the flowers', () {
      expect(
        riverRescueStars(
            heartsRemaining: 2, lotusCollected: 50, lotusAvailable: 100),
        2,
      );
      expect(
        riverRescueStars(
            heartsRemaining: 2, lotusCollected: 49, lotusAvailable: 100),
        1,
      );
      expect(
        riverRescueStars(
            heartsRemaining: 1, lotusCollected: 100, lotusAvailable: 100),
        1,
      );
    });

    test('finishing with nothing left is still worth a star', () {
      // There is no game over in River Rescue: the basket always reaches the
      // princess, so the floor is a star and never zero.
      expect(
        riverRescueStars(
            heartsRemaining: 0, lotusCollected: 0, lotusAvailable: 100),
        1,
      );
    });
  });

  // ------------------------------------------------------------------ widget

  Widget harness({ValueChanged<RiverMove>? onMove}) {
    return ChangeNotifierProvider<TextToSpeechService>(
      create: (_) => TextToSpeechService(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RiverRescueGame(
          definition: kidsZoneGameForStop('moses_1')!,
          stopTitle: 'Level 1 — River Rescue',
          adventureTitle: 'Baby Moses',
          onComplete: (_) {},
          onMove: onMove,
        ),
      ),
    );
  }

  void sizeAsHandset(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Advances the game's Ticker. A single long pump renders one frame, which
  /// the tick loop clamps to 50ms — nowhere near enough to leave the intro.
  Future<void> run(WidgetTester tester, double seconds) async {
    for (int i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('lays out on a handset without overflowing',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await run(tester, 3);

    expect(tester.takeException(), isNull);
    expect(find.byType(RiverRescueGame), findsOneWidget);
  });

  testWidgets('hop, duck and paddle are reachable without a swipe',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    final List<RiverMove> moves = <RiverMove>[];
    await tester.pumpWidget(harness(onMove: moves.add));
    await run(tester, 3);

    for (final String label in <String>['Hop', 'Duck', 'Paddle']) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
    }

    expect(moves, <RiverMove>[RiverMove.hop, RiverMove.duck, RiverMove.boost]);
  });

  testWidgets('a swipe left and a tap on the left third do the same thing',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    final List<RiverMove> moves = <RiverMove>[];
    await tester.pumpWidget(harness(onMove: moves.add));
    await run(tester, 3);

    final Finder river = find.byType(RiverSceneView);
    final Rect box = tester.getRect(river);

    await tester.fling(river, const Offset(-120, 0), 900);
    await tester.pump();
    await tester.tapAt(Offset(box.left + box.width * 0.15, box.center.dy));
    await tester.pump();

    expect(moves, <RiverMove>[RiverMove.laneLeft, RiverMove.laneLeft]);
  });

  testWidgets('with a screen reader on, every lane has its own button',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    final List<RiverMove> moves = <RiverMove>[];

    await tester.pumpWidget(
      MediaQuery(
        // TalkBack eats one-finger swipes, so the gesture layer is not a
        // fallback here — the buttons are the only way in.
        data: const MediaQueryData(accessibleNavigation: true),
        child: harness(onMove: moves.add),
      ),
    );
    await run(tester, 3);

    for (final String label in <String>['Left', 'Middle', 'Right']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }

    await tester.tap(find.bySemanticsLabel('Left'));
    await tester.pump();
    expect(moves, <RiverMove>[RiverMove.laneLeft]);
  });

  testWidgets('the princess beat cannot be tapped away',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    final List<RiverMove> moves = <RiverMove>[];
    await tester.pumpWidget(harness(onMove: moves.add));

    // Long enough to clear the 2.2s stage intro plus the whole of stage 1
    // (~18s) and land inside the 3s arrival window that follows — but not so
    // long that the window has already closed into stage-cleared.
    await run(tester, 21.5);
    expect(
        find.text('Someone is watching from the riverbank...'), findsOneWidget);

    // Hammering the screen during the narration neither skips it nor steers.
    final Rect box = tester.getRect(find.byType(RiverSceneView));
    for (int i = 0; i < 5; i++) {
      await tester.tapAt(box.center);
      await tester.pump();
    }
    expect(moves, isEmpty);
    expect(
        find.text('Someone is watching from the riverbank...'), findsOneWidget);
  });

  testWidgets(
      'a slow, short drag registers a lane change without waiting for release',
      (WidgetTester tester) async {
    // The old detector fired on release velocity, so a young child's slow,
    // short swipe often produced nothing — the movement never built up enough
    // speed. Fairness here is checked by drag *distance*, so this fires the
    // instant the finger has moved far enough, with the pointer still down.
    sizeAsHandset(tester);
    final List<RiverMove> moves = <RiverMove>[];
    await tester.pumpWidget(harness(onMove: moves.add));
    await run(tester, 3);

    final Rect box = tester.getRect(find.byType(RiverSceneView));
    final TestGesture gesture = await tester.startGesture(box.center);

    // A slow crawl, well under any velocity threshold a release-based
    // detector would have required — 10 steps of 6px each, one per frame.
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Fired already, with the finger still on the glass.
    expect(moves, <RiverMove>[RiverMove.laneLeft]);

    await gesture.up();
    await tester.pump();
    expect(moves, <RiverMove>[RiverMove.laneLeft]);
  });

  testWidgets(
      'a determined child reaches the crocodile stage well inside a minute',
      (WidgetTester tester) async {
    // The stage that introduces the crocodile is gated behind finishing
    // stages 1 and 2, and used to take about 90 seconds of play to reach.
    // This walks the whole path — including tapping past each stage-cleared
    // card, which the child controls, not a timer — and checks the total
    // comes in well under a minute of actual river time.
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());

    // Clear the stage-1 intro, run the stage, and land past its arrival beat
    // in stage-cleared. The buffer beyond each stage's own `approximateSeconds`
    // (already checked elsewhere to be well under a minute combined) is just
    // slack for `run()`'s 16ms pump steps landing a hair under real 60fps time.
    await run(tester, 2.6 + stages[0].approximateSeconds + 5.0);
    expect(find.text('You made it!'), findsOneWidget);

    await tester.tap(find.text('Keep floating'));
    await tester.pump();

    await run(tester, 2.6 + stages[1].approximateSeconds + 5.0);
    expect(find.text('You made it!'), findsOneWidget);

    await tester.tap(find.text('Keep floating'));
    await tester.pump();

    // Stage 3's intro card names the stage the moment it opens — no need to
    // wait out its own run to prove the crocodile stage was reached. Together
    // with 'each stage lands in its intended play time' (stages 1 and 2 sum
    // to well under a minute of actual river time), this is the fix for the
    // original complaint: the crocodile used to be ~90 seconds away.
    expect(find.text('Near the Palace'), findsOneWidget);
  });

  testWidgets(
      'losing a heart shows a reassuring toast, which then clears itself',
      (WidgetTester tester) async {
    // Stage 1's only centre-lane hazard sits at 87.6m; a basket that never
    // moves off the centre lane collides with nothing before it and exactly
    // that afterwards — a deterministic, single bump with no input at all.
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());

    await run(tester, 18);
    expect(find.text('A splash! 2 hearts left — try again!'), findsOneWidget);

    // The toast has its own multi-second clock, separate from the bump's
    // own much shorter animation — long enough to actually be read.
    await run(tester, 4);
    expect(find.text('A splash! 2 hearts left — try again!'), findsNothing);
  });

  testWidgets('a fresh stage announces its hearts are full again',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());

    await run(tester, 2.6 + stages[0].approximateSeconds + 5.0);
    expect(find.text('You made it!'), findsOneWidget);

    await tester.tap(find.text('Keep floating'));
    await tester.pump();

    expect(find.text('Fresh hearts — a new chance for this stretch!'),
        findsOneWidget);
  });
}
