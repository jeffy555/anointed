import 'package:anointed/features/kids_zone/games/listen_and_answer_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:anointed/widgets/gameplay_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Level 1 narrows the answer choices as it goes. The ramp only builds tension
/// if the distractors that survive the trim are the closest near-misses, so the
/// data has to carry enough of them in the right order.
void main() {
  List<ListeningQuestion> questions() =>
      kidsZoneGameForStop('garden_1')!.listeningQuestions;

  group('God\'s Questions difficulty ramp', () {
    test('there is one ramp entry per question', () {
      expect(questions().length, kGenesisLevel1OptionRamp.length);
    });

    test('the ramp narrows 4 to 3 to 2 and never widens', () {
      expect(kGenesisLevel1OptionRamp.first, 4);
      expect(kGenesisLevel1OptionRamp.last, 2);
      for (int i = 1; i < kGenesisLevel1OptionRamp.length; i++) {
        expect(
          kGenesisLevel1OptionRamp[i],
          lessThanOrEqualTo(kGenesisLevel1OptionRamp[i - 1]),
          reason: 'question ${i + 1} offers more choices than the one before',
        );
      }
      expect(kGenesisLevel1OptionRamp.toSet(), <int>{4, 3, 2});
    });

    test('every question can supply the widest step of the ramp', () {
      final int widest = kGenesisLevel1OptionRamp.reduce(
        (int a, int b) => a > b ? a : b,
      );
      for (final ListeningQuestion q in questions()) {
        expect(
          q.allOptions.length,
          greaterThanOrEqualTo(widest),
          reason: '"${q.prompt}" cannot fill $widest options',
        );
      }
    });

    test('answers are distinct, so no question has two right-looking taps', () {
      for (final ListeningQuestion q in questions()) {
        expect(
          q.allOptions.toSet().length,
          q.allOptions.length,
          reason: '"${q.prompt}" repeats an option',
        );
        expect(q.distractors, isNotEmpty);
        expect(q.distractors, isNot(contains(q.correctAnswer)));
      }
    });

    test('every question has a prompt worth listening to', () {
      for (final ListeningQuestion q in questions()) {
        expect(q.prompt.trim(), isNotEmpty);
        expect(q.prompt.trim(), endsWith('?'));
        expect(q.correctAnswer.trim(), isNotEmpty);
      }
    });

    test('the two-option finale still keeps a genuine near-miss', () {
      // The last questions trim to a single distractor — the first listed.
      final List<ListeningQuestion> qs = questions();
      for (int i = 0; i < qs.length; i++) {
        if (kGenesisLevel1OptionRamp[i] != 2) continue;
        expect(
          qs[i].distractors.first.trim(),
          isNotEmpty,
          reason: 'question ${i + 1} has no near-miss to pair against',
        );
      }
    });
  });

  group('listening-first flow', () {
    Widget harness() {
      return ChangeNotifierProvider<TextToSpeechService>(
        create: (_) => TextToSpeechService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListenAndAnswerGame(
            definition: kidsZoneGameForStop('garden_1')!,
            stopTitle: 'Level 1 — God\'s Questions',
            adventureTitle: 'Creation Garden',
            onComplete: (_) {},
          ),
        ),
      );
    }

    testWidgets('hides the answers until the question has been read',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump();

      // Reading aloud: the prompt is on screen but nothing is answerable yet.
      expect(find.byType(AnswerOptionButton), findsNothing);
      expect(find.byIcon(Icons.hearing_rounded), findsOneWidget);

      // Once the listening beat elapses the choices arrive.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AnswerOptionButton), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens with the widest step of the ramp',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(AnswerOptionButton),
        findsNWidgets(kGenesisLevel1OptionRamp.first),
      );
    });
  });
}
