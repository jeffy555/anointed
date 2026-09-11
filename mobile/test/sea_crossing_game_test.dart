import 'package:anointed/features/kids_zone/games/sea_crossing_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/features/kids_zone/widgets/parted_sea_view.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Sea Crossing ends the way the account does: the waters return over
/// Pharaoh's chariots. That was a deliberate product decision, taken over the
/// "keep the miracle, drop the outcome" approach used elsewhere in Kids Zone.
///
/// What these tests hold is what the decision was bounded by — the sinking is
/// the *last* thing that happens, it cannot start before the walls have
/// actually met, the pursuit never reaches the ground the people are standing
/// on, and no amount of bad tapping can fail the child out of the phase.
void main() {
  final List<SeaPhase> phases = kidsZoneGameForStop('moses_3')!.seaPhases;

  /// Runs a whole phase-3 sequence, calling [check] after every tick.
  ///
  /// [hits] is how many taps land, spread through the phase — the invariants
  /// have to hold for a child who taps perfectly, one who taps badly, and one
  /// who never taps at all.
  void runSequence(
    void Function(SeaClosingSequence sea) check, {
    required int hits,
  }) {
    final SeaClosingSequence sea = SeaClosingSequence();
    int delivered = 0;
    for (int step = 0; step < 6000; step++) {
      if (delivered < hits && step % 30 == 0 && step > 0) {
        sea.registerHit();
        delivered++;
      }
      sea.tick(1 / 60);
      check(sea);
      if (sea.finished) return;
    }
    fail('the sequence never finished with $hits hits — it must always end');
  }

  group('the ending stays where it was agreed', () {
    for (final int hits in <int>[0, 1, 6, 12]) {
      test('with $hits taps, nothing sinks before the waters have met', () {
        // The sinking is the consequence of the sea closing, so it can never
        // begin while there is still a gap. This is what keeps the beat
        // readable as "the water came back" rather than as chariots simply
        // falling over.
        runSequence(
          (SeaClosingSequence sea) {
            if (sea.sink > 0) {
              expect(
                sea.seaClose,
                1.0,
                reason: 'chariots began sinking while the walls were only '
                    '${(sea.seaClose * 100).round()}% closed',
              );
            }
          },
          hits: hits,
        );
      });

      test('with $hits taps, the pursuit never reaches the far shore', () {
        // The people are across before the chariots appear, and the chariots
        // stop well short of them. The two are never on the same ground.
        runSequence(
          (SeaClosingSequence sea) {
            expect(sea.chariotAdvance,
                lessThanOrEqualTo(SeaClosingSequence.maxAdvance + 0.001));
          },
          hits: hits,
        );
      });
    }

    test('the phase always ends, however badly or little the child taps', () {
      // No fail state and no dead end: zero taps still finishes, on patience.
      runSequence((_) {}, hits: 0);
      runSequence((_) {}, hits: 30);
    });

    test('tapping closes the sea sooner than not tapping', () {
      double finishTime(int hits) {
        final SeaClosingSequence sea = SeaClosingSequence();
        int delivered = 0;
        for (int step = 0; step < 6000; step++) {
          if (delivered < hits && step % 12 == 0 && step > 0) {
            sea.registerHit();
            delivered++;
          }
          sea.tick(1 / 60);
          if (sea.finished) return sea.elapsed;
        }
        return double.infinity;
      }

      expect(
          finishTime(SeaClosingSequence.hitsToClose), lessThan(finishTime(0)));
    });

    test('the sea only ever closes further, never back open', () {
      double last = 0;
      runSequence(
        (SeaClosingSequence sea) {
          expect(sea.seaClose, greaterThanOrEqualTo(last - 1e-9));
          last = sea.seaClose;
        },
        hits: 6,
      );
    });

    test('taps after the waters meet change nothing', () {
      final SeaClosingSequence sea = SeaClosingSequence();
      for (int i = 0; i < 200 && sea.stage != SeaClosingStage.swallowed; i++) {
        sea.registerHit();
        sea.tick(1 / 60);
      }
      expect(sea.stage, SeaClosingStage.swallowed);
      final int hitsAtClose = sea.hits;
      sea.registerHit();
      expect(sea.hits, hitsAtClose);
    });
  });

  group('scoring is unchanged by the new phase', () {
    test('only phases 1 and 2 are scored', () {
      expect(
        phases.where((SeaPhase p) => p.isScored).map((SeaPhase p) => p.id),
        <String>['raise_the_staff', 'walk_through'],
      );
      expect(
        phases.where((SeaPhase p) => !p.isScored).map((SeaPhase p) => p.id),
        <String>['turn_back_army', 'celebration'],
      );
    });

    test('the scored total counts only those two phases beats', () {
      final int expected = phases
          .where((SeaPhase p) => p.isScored)
          .fold(0, (int sum, SeaPhase p) => sum + p.beats.length);
      expect(kSeaScoredBeats, expected);

      // Stated numerically too, so an edit that folds phase 3 or 4 in shows
      // up here as a changed number rather than as a silently easier game.
      expect(kSeaScoredBeats, 20);
    });

    test('stars read the scored beats and nothing else', () {
      expect(seaCrossingStars(hits: 20), 3);
      expect(seaCrossingStars(hits: 17), 3);
      expect(seaCrossingStars(hits: 16), 2);
      expect(seaCrossingStars(hits: 11), 2);
      expect(seaCrossingStars(hits: 10), 1);
      expect(seaCrossingStars(hits: 0), 1);
    });
  });

  group('the phases tell the story in the right order', () {
    test('turning the army back comes before the celebration', () {
      // The singing is the reaction to the danger leaving, so it cannot come
      // first.
      final List<String> ids = phases.map((SeaPhase p) => p.id).toList();
      expect(ids, <String>[
        'raise_the_staff',
        'walk_through',
        'turn_back_army',
        'celebration',
      ]);
    });

    test('phase 3 uses the deliberate hand beat, not the rhythm circle', () {
      final SeaPhase army =
          phases.firstWhere((SeaPhase p) => p.id == 'turn_back_army');
      expect(
          army.beats.every((SeaBeat b) => b.kind == SeaBeatKind.hand), isTrue);
      // Fewer and wider-set than the walk-through it follows.
      final SeaPhase walk =
          phases.firstWhere((SeaPhase p) => p.id == 'walk_through');
      expect(army.beats.length, lessThan(walk.beats.length));
      expect(army.beats.length, inInclusiveRange(6, 8));
    });

    test('the level sits last in the Moses adventure', () {
      final KidsAdventure moses = kidsZoneAdventureById('moses_nile')!;
      expect(moses.stops.last.id, 'moses_3');
      expect(moses.stops.last.gameKind, KidsZoneGameKind.seaCrossing);
    });
  });

  group('the targets move around and have to be hit', () {
    test('phase 3 keeps its deliberate hand beats', () {
      final SeaPhase army =
          phases.firstWhere((SeaPhase p) => p.id == 'turn_back_army');
      expect(
          army.beats.every((SeaBeat b) => b.kind == SeaBeatKind.hand), isTrue);
    });
  });

  group('the sinking is actually reached and actually drawn', () {
    test('the sequence spends real time with chariots part-way under', () {
      // Not just "sink hits 1 eventually" — there has to be a stretch where
      // they are visibly going down, or the beat passes in a single frame.
      final SeaClosingSequence sea = SeaClosingSequence();
      int partWay = 0;
      for (int step = 0; step < 6000 && !sea.finished; step++) {
        if (step % 20 == 0) sea.registerHit();
        sea.tick(1 / 60);
        if (sea.sink > 0.05 && sea.sink < 0.95) partWay++;
      }
      expect(sea.sink, 1.0);
      expect(partWay, greaterThan(60),
          reason: 'the chariots went under in under a second of frames');
    });

    test('the scene is still showing chariots while they sink', () {
      // The painter skips them entirely below this threshold, so if the
      // sequence ever parked them off-path before sinking, nothing would
      // draw. This is the value the widget passes straight to the painter.
      final SeaClosingSequence sea = SeaClosingSequence();
      for (int step = 0; step < 6000 && !sea.finished; step++) {
        if (step % 20 == 0) sea.registerHit();
        sea.tick(1 / 60);
        if (sea.sink > 0) {
          expect(sea.chariotAdvance, greaterThan(-0.05),
              reason: 'chariots were off-path while sinking, so the painter '
                  'would draw nothing');
        }
      }
    });
  });

  // ------------------------------------------------------------------ widget

  testWidgets('renders the parted sea and takes taps',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<TextToSpeechService>(
        create: (_) => TextToSpeechService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeaCrossingGame(
            definition: kidsZoneGameForStop('moses_3')!,
            stopTitle: 'Level 3 — Crossing the Sea',
            adventureTitle: 'Baby Moses',
            onComplete: (_) {},
          ),
        ),
      ),
    );

    for (int i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(PartedSeaView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap has to land on the target, not just at the right time',
      (WidgetTester tester) async {
    // The timing window alone made this a metronome the child could answer
    // without looking at the screen. Tapping a far corner while a target is
    // live must not count.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<TextToSpeechService>(
        create: (_) => TextToSpeechService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeaCrossingGame(
            definition: kidsZoneGameForStop('moses_3')!,
            stopTitle: 'Level 3',
            adventureTitle: 'Baby Moses',
            onComplete: (_) {},
          ),
        ),
      ),
    );

    // Pump until a target is actually live. Waiting a fixed number of frames
    // and giving up would let this test pass without checking anything,
    // which is worse than no test at all.
    final Finder target = find.byKey(const ValueKey<String>('sea-target'));
    bool found = false;
    for (int i = 0; i < 900 && !found; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      found = target.evaluate().isNotEmpty;
    }
    expect(found, isTrue, reason: 'no tap target ever appeared');

    final Rect box = tester.getRect(target);
    final Rect screen = tester.getRect(find.byType(PartedSeaView));

    // A corner as far from the live target as the screen allows.
    final Offset far = box.center.dx < screen.center.dx
        ? Offset(screen.right - 8, screen.bottom - 8)
        : Offset(screen.left + 8, screen.bottom - 8);
    await tester.tapAt(far);
    await tester.pump();

    // The target is still live: a miss in space does not claim the beat.
    expect(find.byKey(const ValueKey<String>('sea-target')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
