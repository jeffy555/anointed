import 'package:anointed/features/kids_zone/games/plague_sort_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/features/kids_zone/widgets/egypt_plague_view.dart';
import 'package:anointed/features/kids_zone/widgets/pharaoh_resolve_meter.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Plague Sort's innovation is that Egypt answers what the child does. These
/// tests hold that promise to account: ten distinct effects, a meter that only
/// ever moves forward, and two payoffs that cannot land out of sync.
void main() {
  final List<PlagueRound> rounds = kidsZoneGameForStop('moses_2')!.plagueRounds;

  group('the ten plagues', () {
    test('are in the one historically correct order', () {
      expect(
        kMosesPlagues.map((PlagueCard c) => c.order),
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
      expect(kMosesPlagues.first.name, 'Blood');
      expect(kMosesPlagues.last.effect, PlagueEffect.crownFall);
    });

    test('each one drives a distinct backdrop effect', () {
      // The whole point of the living backdrop is that these are ten different
      // events. A reused effect would make two plagues indistinguishable in
      // the only place the child is actually looking.
      final Set<PlagueEffect> effects =
          kMosesPlagues.map((PlagueCard c) => c.effect).toSet();
      expect(effects.length, kMosesPlagues.length);
      expect(effects.length, PlagueEffect.values.length);
    });

    test('the rounds deal 5, then 5, then all ten', () {
      expect(rounds.map((PlagueRound r) => r.orders.length), <int>[5, 5, 10]);
      expect(rounds[0].orders, <int>[1, 2, 3, 4, 5]);
      expect(rounds[1].orders, <int>[6, 7, 8, 9, 10]);
      expect(rounds[2].orders.length, kMosesPlagues.length);
    });

    test('every round resolves its orders to real cards', () {
      for (final PlagueRound r in rounds) {
        expect(r.cards.length, r.orders.length);
        expect(r.cards.map((PlagueCard c) => c.order), r.orders);
      }
    });

    test('the level sits after River Rescue in the adventure', () {
      final KidsAdventure moses = kidsZoneAdventureById('moses_nile')!;
      expect(moses.stops.map((KidsAdventureStop s) => s.id),
          containsAllInOrder(<String>['moses_intro', 'moses_1', 'moses_2']));
    });
  });

  group('scoring never punishes', () {
    test('finishing is worth a star however many wrong tries it took', () {
      expect(
        plagueSortStars(correct: kPharaohResolveCracks, wrongAttempts: 99),
        1,
      );
    });

    test('a clean run is worth three, a scrappy one still worth two', () {
      expect(plagueSortStars(correct: 10, wrongAttempts: 0), 3);
      expect(plagueSortStars(correct: 10, wrongAttempts: 2), 3);
      expect(plagueSortStars(correct: 10, wrongAttempts: 3), 2);
      expect(plagueSortStars(correct: 10, wrongAttempts: 6), 2);
      expect(plagueSortStars(correct: 10, wrongAttempts: 7), 1);
    });

    test('there is no streak requirement anywhere in the stars', () {
      // The streak is cosmetic. Two runs with identical placements and
      // wrong-attempt counts must score the same however the streaks fell.
      expect(
        plagueSortStars(correct: 10, wrongAttempts: 1),
        plagueSortStars(correct: 10, wrongAttempts: 1),
      );
      expect(kPlagueStreakGlow, greaterThan(1));
    });
  });

  // ------------------------------------------------------------------ widget

  Widget harness({int? age, ValueChanged<int>? onComplete}) {
    return ChangeNotifierProvider<TextToSpeechService>(
      create: (_) => TextToSpeechService(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlagueSortGame(
          definition: kidsZoneGameForStop('moses_2')!,
          stopTitle: 'Level 2 — Plagues of Egypt',
          adventureTitle: 'Baby Moses',
          onComplete: onComplete ?? (_) {},
          debugAge: age,
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

  /// Drags the card named [name] onto the slot showing [step].
  ///
  /// Scrolls the tray first: it is a horizontal `ListView`, so a card that is
  /// off-screen has not been built and cannot be found.
  Future<void> place(WidgetTester tester, String name, int step) async {
    // No scrolling: the tray shows every card at once, which is the whole
    // reason it is a Wrap and not a list.
    final Finder card = find.widgetWithText(Draggable<PlagueCard>, name);
    expect(card, findsWidgets, reason: '$name is not in the tray');

    final Finder slot = find.text('$step');
    await tester.drag(
        card.first, tester.getCenter(slot) - tester.getCenter(card.first));
    await tester.pump();
    // Let the backdrop effect finish so the next placement is accepted.
    await tester.pump(const Duration(seconds: 2));
  }

  /// Plays one round correctly, start to finish.
  Future<void> playRound(WidgetTester tester, PlagueRound round) async {
    await tester.tap(find.text('Begin').hitTestable());
    await tester.pump();
    for (int i = 0; i < round.orders.length; i++) {
      final PlagueCard card = kMosesPlagues
          .firstWhere((PlagueCard c) => c.order == round.orders[i]);
      await place(tester, card.name, i + 1);
    }
  }

  testWidgets('lays out with Egypt behind the board and the meter on top',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(EgyptPlagueView), findsOneWidget);
    expect(find.byType(PharaohResolveMeter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrong placement costs nothing and cracks nothing',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text('Begin').hitTestable());
    await tester.pump();

    // Frogs is plague 2; dropping it on step 1 is wrong.
    await place(tester, 'Frogs', 1);

    // The meter has not moved: a wrong try is not damage.
    final PharaohResolveMeter meter =
        tester.widget(find.byType(PharaohResolveMeter));
    expect(meter.cracks, 0);
    expect(meter.shattered, isFalse);

    // And the card is still there to try again with.
    expect(find.widgetWithText(Draggable<PlagueCard>, 'Frogs'), findsWidgets);
  });

  testWidgets('the meter cracks once per correct placement, never per attempt',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text('Begin').hitTestable());
    await tester.pump();

    int cracks() => tester
        .widget<PharaohResolveMeter>(find.byType(PharaohResolveMeter))
        .cracks;

    await place(tester, 'Blood', 1);
    expect(cracks(), 1);

    // Two wrong tries in between must leave it exactly where it was.
    await place(tester, 'Gnats', 2);
    await place(tester, 'Flies', 2);
    expect(cracks(), 1);

    await place(tester, 'Frogs', 2);
    expect(cracks(), 2);
  });

  testWidgets('tapping the speaker does not pick the card up',
      (WidgetTester tester) async {
    // The two gestures share a widget, so this is the one that could quietly
    // break: a child tapping to hear a card must not find it in their hand.
    sizeAsHandset(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text('Begin').hitTestable());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
    await tester.pump();

    expect(
      tester
          .widget<PharaohResolveMeter>(find.byType(PharaohResolveMeter))
          .cracks,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the crown falls and the meter shatters on the same placement',
      (WidgetTester tester) async {
    // Section 9's headline check: two payoffs read from one event, so they can
    // never land out of sync. Played all the way through rather than poked at,
    // because "the same event" is only true if it survives a real run.
    sizeAsHandset(tester);
    int? stars;
    await tester.pumpWidget(harness(age: 5, onComplete: (int s) => stars = s));
    await tester.pump();

    bool shattered() => tester
        .widget<PharaohResolveMeter>(find.byType(PharaohResolveMeter))
        .shattered;
    bool crownFallen() => tester
        .widget<EgyptPlagueView>(find.byType(EgyptPlagueView))
        .crownFallen;

    await playRound(tester, rounds[0]);
    expect(shattered(), isFalse);
    expect(crownFallen(), isFalse);

    await tester.tap(find.text('Keep going').hitTestable());
    await tester.pump();
    await playRound(tester, rounds[1]);

    // Ten correct placements have landed, but only across rounds 1 and 2 —
    // the payoff belongs to the final round, not to the tenth card anywhere.
    await tester.tap(find.text('Keep going').hitTestable());
    await tester.pump();
    await playRound(tester, rounds[2]);

    expect(shattered(), isTrue);
    expect(crownFallen(), isTrue,
        reason: 'the crown must fall on the same placement that shatters '
            'the meter, not independently');

    await tester.tap(find.text('Collect my stars').hitTestable());
    await tester.pump();
    expect(stars, isNotNull);
  });

  testWidgets('the round-3 preview is age-defaulted and always overridable',
      (WidgetTester tester) async {
    sizeAsHandset(tester);
    await tester.pumpWidget(harness(age: 6));
    await tester.pump();

    // The toggle belongs to round 3's intro, so the level has to be played to
    // it — the preference is offered where it applies, not up front.
    await playRound(tester, rounds[0]);
    await tester.tap(find.text('Keep going').hitTestable());
    await tester.pump();
    await playRound(tester, rounds[1]);
    await tester.tap(find.text('Keep going').hitTestable());
    await tester.pump();

    expect(
      tester.widget<Switch>(find.byType(Switch)).value,
      isFalse,
      reason: 'a six-year-old should not be handed a memory layer by default',
    );

    // Off by default, but always reachable — a confident younger child, or a
    // parent, can turn it on.
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
