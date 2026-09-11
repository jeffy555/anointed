import 'package:anointed/features/kids_zone/games/moses_intro_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/features/kids_zone/widgets/moses_intro_view.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Baby Moses introduction is stop 0 of the adventure, so it is the first
/// thing a child meets and the gate River Rescue sits behind.
void main() {
  final List<MosesIntroScene> scenes =
      kidsZoneGameForStop('moses_intro')!.mosesScenes;

  group('the story is told before the level is played', () {
    test('the adventure opens with the introduction, then River Rescue', () {
      final KidsAdventure moses = kidsZoneAdventureById('moses_nile')!;

      // Order is the gate: the hub unlocks stop n only once stop n-1 is done,
      // so putting the story first is what keeps a child from being handed a
      // basket to steer before being told whose basket it is.
      expect(moses.stops.first.id, 'moses_intro');
      expect(moses.stops.first.gameKind, KidsZoneGameKind.mosesIntro);
      expect(moses.stops[1].id, 'moses_1');
      expect(moses.stops[1].gameKind, KidsZoneGameKind.riverRescue);
    });

    test('every beat has narration, a label and a backdrop', () {
      expect(scenes, isNotEmpty);
      for (final MosesIntroScene s in scenes) {
        expect(s.sceneLabel.trim(), isNotEmpty);
        expect(s.narration.trim(), isNotEmpty);
      }
    });

    test('the story runs from Egypt to the promise', () {
      expect(scenes.first.era, MosesEra.egypt);
      expect(scenes.last.era, MosesEra.promise);

      // The arc has to actually pass through the river — that is the beat
      // River Rescue picks up from.
      expect(
        scenes.map((MosesIntroScene s) => s.era),
        contains(MosesEra.river),
      );
    });

    test('every beat shows people, not floating props', () {
      // The first version popped Material icons onto the backdrop, so the
      // story read as a shopping-basket glyph hovering on its own with nobody
      // around it. Every beat has to carry at least one human figure.
      const Set<MosesFigureKind> peopled = <MosesFigureKind>{
        MosesFigureKind.family,
        MosesFigureKind.worker,
        MosesFigureKind.motherHolding,
        MosesFigureKind.motherWeaving,
        MosesFigureKind.girlWatching,
        MosesFigureKind.princessReaching,
        MosesFigureKind.princessHolding,
      };

      for (final MosesIntroScene scene in scenes) {
        expect(scene.figures, isNotEmpty,
            reason: '${scene.sceneLabel} is empty');
        expect(
          scene.figures.any((MosesFigure f) => peopled.contains(f.kind)),
          isTrue,
          reason: '${scene.sceneLabel} has props but no people in it',
        );
      }
    });

    test('the baby is never shown adrift without the basket around him', () {
      // `basketOnWater` paints the swaddled baby inside the basket, which is
      // the only way the baby appears on the water at all — there is no
      // "lone basket" and no "lone baby" figure to place by mistake.
      expect(
        MosesFigureKind.values.map((MosesFigureKind k) => k.name),
        isNot(contains('baby')),
      );
    });

    test('figures stand on the ground, inside the frame', () {
      for (final MosesIntroScene scene in scenes) {
        for (final MosesFigure f in scene.figures) {
          expect(f.left, inInclusiveRange(0.05, 0.95),
              reason: '${scene.sceneLabel}: ${f.kind.name} is off the side');
          // Below the horizon (0.58) so nobody is standing in the sky, and
          // clear of the very bottom edge.
          expect(f.baseline, inInclusiveRange(0.60, 0.95),
              reason:
                  '${scene.sceneLabel}: ${f.kind.name} floats off the ground');
          expect(f.scale, inInclusiveRange(0.5, 2.0));
        }
      }
    });

    test('the backdrop changes with the story rather than sitting still', () {
      // Each era paints a different sky. If two eras resolved to the same
      // gradient the backdrop would be claiming to tell a story it is not.
      final Set<MosesEra> eras =
          scenes.map((MosesIntroScene s) => s.era).toSet();
      final List<List<Color>> skies = eras
          .map((MosesEra e) => mosesSkyFor(e).colors)
          .toList(growable: false);

      for (int i = 0; i < skies.length; i++) {
        for (int j = i + 1; j < skies.length; j++) {
          expect(skies[i], isNot(orderedEquals(skies[j])));
        }
      }
    });
  });

  group('the narrator voice', () {
    test('is deeper and slower than the everyday read-aloud voice', () {
      // The platform engine offers no second voice, so "a bigger voice" has
      // to be built from pitch and rate. If these ever converge, the story
      // stops sounding different from a quiz prompt.
      expect(TtsVoice.narrator.pitch, lessThan(TtsVoice.friendly.pitch));
      expect(TtsVoice.narrator.rate, lessThan(TtsVoice.friendly.rate));
    });
  });

  // ------------------------------------------------------------------ widget

  Widget harness() {
    return ChangeNotifierProvider<TextToSpeechService>(
      create: (_) => TextToSpeechService(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MosesIntroGame(
          definition: kidsZoneGameForStop('moses_intro')!,
          stopTitle: 'Introduction',
          adventureTitle: 'Baby Moses',
          onComplete: (_) {},
        ),
      ),
    );
  }

  /// Waits out the narration hold that keeps the Next button disabled while a
  /// beat is being read — comfortably past the 9s ceiling. Not `pumpAndSettle`:
  /// the backdrop animates forever, so nothing ever settles.
  Future<void> waitForNarration(WidgetTester tester) async {
    for (int i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  void sizeAsHandset(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('opens on the first beat and steps through the story',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text(scenes.first.sceneLabel), findsOneWidget);
    expect(find.byType(MosesIntroView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await waitForNarration(tester);
    await tester.tap(find.text('Next part'));
    await tester.pump();
    expect(find.text(scenes[1].sceneLabel), findsOneWidget);
  });

  testWidgets('a silent TTS engine never strands the child in the story',
      (WidgetTester tester) async {
    // No TTS engine answers in a test, which is exactly the device case that
    // used to matter: `speak()` can return without speech ever reporting that
    // it finished. The Next button has to come back regardless, or the only
    // way out of the introduction is to kill the app.
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    await waitForNarration(tester);

    final Finder next = find.widgetWithText(FilledButton, 'Next part');
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('the last beat hands the child on to Level 1',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    int? stars;
    await tester.pumpWidget(
      ChangeNotifierProvider<TextToSpeechService>(
        create: (_) => TextToSpeechService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MosesIntroGame(
            definition: kidsZoneGameForStop('moses_intro')!,
            stopTitle: 'Introduction',
            adventureTitle: 'Baby Moses',
            onComplete: (int s) => stars = s,
          ),
        ),
      ),
    );
    await tester.pump();

    for (int i = 0; i < scenes.length - 1; i++) {
      await waitForNarration(tester);
      await tester.tap(find.text('Next part'));
      await tester.pump();
    }
    await waitForNarration(tester);

    // The final button says where it goes, rather than another "Next part".
    expect(find.text('Begin Level 1'), findsOneWidget);
    await tester.tap(find.text('Begin Level 1'));
    await tester.pump();
    expect(stars, 3);
  });
}
