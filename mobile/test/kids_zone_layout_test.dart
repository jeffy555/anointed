// Every Kids Zone stop, rendered at every frame the app can actually put it
// in, asserting that nothing overflows.
//
// This suite exists because 21 of these combinations were broken at once and
// nothing was watching: four stops ran off a 360x720 phone at the default text
// size, six more in landscape, and eleven at a text scale the in-app "Large
// text" switch reaches on its own. The old tests checked two portrait sizes at
// scale 1.0, which is exactly the case that worked.
//
// 2.4 is the app's own ceiling (see the textScaler clamp in app.dart), so it is
// the real contract rather than a stress test. Landscape stays in even though
// the hub asks for portrait: setPreferredOrientations is a request, and large
// screens can decline it.
import 'package:anointed/core/local_store.dart';
import 'package:anointed/features/kids_zone/games/animal_care_game.dart';
import 'package:anointed/features/kids_zone/games/animal_matching_game.dart';
import 'package:anointed/features/kids_zone/games/archery_game.dart';
import 'package:anointed/features/kids_zone/games/ark_builder_game.dart';
import 'package:anointed/features/kids_zone/games/battle_intro_game.dart';
import 'package:anointed/features/kids_zone/games/connect_creations_game.dart';
import 'package:anointed/features/kids_zone/games/creation_intro_game.dart';
import 'package:anointed/features/kids_zone/games/explorer_game.dart';
import 'package:anointed/features/kids_zone/games/jumbled_words_game.dart';
import 'package:anointed/features/kids_zone/games/listen_and_answer_game.dart';
import 'package:anointed/features/kids_zone/games/moses_intro_game.dart';
import 'package:anointed/features/kids_zone/games/noah_intro_game.dart';
import 'package:anointed/features/kids_zone/games/plague_sort_game.dart';
import 'package:anointed/features/kids_zone/games/river_rescue_game.dart';
import 'package:anointed/features/kids_zone/games/sea_crossing_game.dart';
import 'package:anointed/features/kids_zone/games/story_path_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    // Listen & Answer opens by narrating, and without an engine on the other
    // end of the channel its wait for speech-that-never-starts is left pending
    // when the test ends. Answering the channel lets that wait resolve.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => 1,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(
      await SharedPreferences.getInstance(),
      const FlutterSecureStorage(),
    );
  });

  Widget build(String stopId) {
    final KidsZoneGameDefinition d = kidsZoneGameForStop(stopId)!;
    const String t = 'Stop';
    const String a = 'Adventure';
    void done(int _) {}
    return switch (d.kind) {
      KidsZoneGameKind.creationIntro => CreationIntroGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.battleIntro => BattleIntroGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.noahIntro => NoahIntroGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.mosesIntro => MosesIntroGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.archery => ArcheryGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.arkBuilder => ArkBuilderGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.animalMatching => AnimalMatchingGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.animalCare => AnimalCareGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.riverRescue => RiverRescueGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.plagueSort => PlagueSortGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.seaCrossing => SeaCrossingGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.listenAndAnswer => ListenAndAnswerGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.connectCreations => ConnectCreationsGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.jumbledWords => JumbledWordsGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.storyPath => StoryPathGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      KidsZoneGameKind.explorer => ExplorerGame(definition: d, stopTitle: t, adventureTitle: a, onComplete: done),
      _ => const SizedBox.shrink(),
    };
  }

  Widget harness(Widget child, double scale) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<LocalStore>.value(value: store),
        ChangeNotifierProvider<TextToSpeechService>(create: (_) => TextToSpeechService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: c!,
        ),
        home: child,
      ),
    );
  }

  const List<String> stops = <String>[
    'creation_intro', 'garden_1', 'garden_2', 'garden_3',
    'siddim_intro', 'siddim_1', 'siddim_2', 'siddim_3',
    'ark_intro', 'ark_1', 'ark_2', 'ark_3',
    'moses_intro', 'moses_1', 'moses_2', 'moses_3',
  ];

  // Physical pixels paired with a dpr that yields the logical size named.
  for (final (String label, Size px, double dpr, double scale)
      in <(String, Size, double, double)>[
    ('360x720 portrait', Size(720, 1440), 2.0, 1.0),
    ('480x1066 portrait', Size(1440, 3200), 3.0, 1.0),
    ('720x360 landscape', Size(1440, 720), 2.0, 1.0),
    ('800x1280 tablet', Size(1600, 2560), 2.0, 1.0),
    ('360x720 at text scale 1.6', Size(720, 1440), 2.0, 1.6),
    ('360x720 at text scale 2.4', Size(720, 1440), 2.0, 2.4),
  ]) {
    for (final String stop in stops) {
      testWidgets('$stop at $label', (WidgetTester tester) async {
        tester.view.physicalSize = px;
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Collected rather than rethrown, so one run names every broken frame
        // instead of stopping at the first — and each one names its own culprit,
        // because "something overflowed" is not enough to act on.
        final List<String> overflows = <String>[];
        final FlutterExceptionHandler? prior = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final String summary = details.exception.toString();
          if (!summary.contains('overflowed')) {
            prior?.call(details);
            return;
          }
          final List<String> lines = details.toString().split('\n');
          final int marker =
              lines.indexWhere((String l) => l.contains('error-causing widget'));
          final String culprit = marker >= 0
              ? lines
                  .skip(marker + 1)
                  .take(4)
                  .map((String l) => l.trim())
                  .where((String l) => l.isNotEmpty)
                  .join(' ')
              : '(culprit not reported)';
          overflows.add('${summary.split('\n').first}  in  $culprit');
        };

        await tester.pumpWidget(harness(build(stop), scale));
        await tester.pump(const Duration(milliseconds: 16));
        // Past Listen & Answer's opening narration beat and the 12s ceiling it
        // waits under, neither of which the binding will let a test end on.
        // The clock is fake, so the wait costs nothing.
        await tester.pump(const Duration(seconds: 13));
        // Unmount before the view size is restored, so the relayout at the
        // default 800x600 test surface does not print overflows for a frame
        // the app never renders.
        await tester.pumpWidget(const SizedBox.shrink());
        FlutterError.onError = prior;
        tester.takeException();

        expect(
          overflows,
          isEmpty,
          reason: '$stop at $label overflowed:\n  ${overflows.join('\n  ')}',
        );
      });
    }
  }
}
