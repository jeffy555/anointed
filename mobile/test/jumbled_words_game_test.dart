import 'package:anointed/features/kids_zone/games/jumbled_words_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level 3 is the most literacy-dependent activity in Creation Garden, so a
/// child who cannot yet read a word must not be able to get stuck on it: after
/// three wrong taps on a sentence the next word is pointed out.
void main() {
  Widget harness({int? stars}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: JumbledWordsGame(
        definition: kidsZoneGameForStop('garden_3')!,
        stopTitle: 'Level 3 — Jumbled Challenge',
        adventureTitle: 'Creation Garden',
        onComplete: (_) {},
      ),
    );
  }

  List<String> firstSentence() =>
      kidsZoneGameForStop('garden_3')!.jumbledSentences.first.words;

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pump();
  }

  /// Taps a bank word that is deliberately NOT the one the sentence needs.
  Future<void> tapAWrongWord(WidgetTester tester, String correctWord) async {
    final List<String> words = firstSentence();
    final String wrong =
        words.firstWhere((String w) => w != correctWord, orElse: () => '');
    expect(wrong, isNotEmpty, reason: 'sentence needs a distinct wrong word');

    await tester.tap(find.text(wrong).last);
    await tester.pump();
    // The rejection flash clears itself.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('no hint is offered before three wrong taps',
      (WidgetTester tester) async {
    await pumpGame(tester);
    final String correct = firstSentence().first;

    for (int i = 0; i < 2; i++) {
      await tapAWrongWord(tester, correct);
    }

    expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after three wrong taps the next word is pointed out',
      (WidgetTester tester) async {
    await pumpGame(tester);
    final String correct = firstSentence().first;

    for (int i = 0; i < 3; i++) {
      await tapAWrongWord(tester, correct);
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
    expect(find.textContaining(correct), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a correct tap clears the hint and the streak',
      (WidgetTester tester) async {
    await pumpGame(tester);
    final List<String> words = firstSentence();

    for (int i = 0; i < 3; i++) {
      await tapAWrongWord(tester, words.first);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);

    // Place the right word; the hint should retire until they struggle again.
    await tester.tap(find.text(words.first).last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('words can only be placed in order', (WidgetTester tester) async {
    await pumpGame(tester);
    final List<String> words = firstSentence();

    // A wrong word must not join the sentence being built.
    await tapAWrongWord(tester, words.first);

    // The built row still shows its placeholder prompt, meaning nothing landed.
    final BuildContext context = tester.element(find.byType(JumbledWordsGame));
    expect(
      find.text(AppLocalizations.of(context).kidsZoneJumbleTapWords),
      findsOneWidget,
    );
  });
}
