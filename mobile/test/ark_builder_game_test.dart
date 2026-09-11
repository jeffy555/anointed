import 'package:anointed/features/kids_zone/games/ark_builder_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:anointed/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Ark Builder reads the blueprint's size to scale its drag feedback.
/// Reading that from the build area's RenderBox during build threw
/// "RenderBox.size called on a render box that does not have a size" on the
/// first frame, because the box is mounted before it is laid out.
void main() {
  Widget harness(Widget child) {
    // The shared game shell renders a ReadAloudButton, which resolves the TTS
    // service from Provider.
    return ChangeNotifierProvider<TextToSpeechService>(
      create: (_) => TextToSpeechService(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('renders its first frame without a layout assertion',
      (WidgetTester tester) async {
    // Match a real handset so the tray lays out the way it does on device.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final KidsZoneGameDefinition definition = kidsZoneGameForStop('ark_1')!;

    await tester.pumpWidget(
      harness(
        ArkBuilderGame(
          definition: definition,
          stopTitle: 'Level 1 — Ark Builder',
          adventureTitle: 'Noah\'s Ark',
          onComplete: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the timber tray once the blueprint has been laid out',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final KidsZoneGameDefinition definition = kidsZoneGameForStop('ark_1')!;

    await tester.pumpWidget(
      harness(
        ArkBuilderGame(
          definition: definition,
          stopTitle: 'Level 1 — Ark Builder',
          adventureTitle: 'Noah\'s Ark',
          onComplete: (_) {},
        ),
      ),
    );
    // The tray holds back one frame while the area size is captured.
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Every stage-1 piece should be reachable in the tray.
    for (final ArkPiece piece in definition.arkStages.first.pieces) {
      expect(
        find.text(piece.label),
        findsWidgets,
        reason: '${piece.label} should be draggable from the tray',
      );
    }
  });

  testWidgets('the wide keel snaps when dropped on its outline',
      (WidgetTester tester) async {
    // Regression: the drop used to add half the piece size to the pointer
    // position, which put wide pieces like the keel permanently out of range.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final KidsZoneGameDefinition definition = kidsZoneGameForStop('ark_1')!;
    final ArkPiece keel = definition.arkStages.first.pieces
        .firstWhere((ArkPiece p) => p.id == 'keel');

    await tester.pumpWidget(
      harness(
        ArkBuilderGame(
          definition: definition,
          stopTitle: 'Level 1 — Ark Builder',
          adventureTitle: 'Noah\'s Ark',
          onComplete: (_) {},
        ),
      ),
    );
    await tester.pump();

    // The blueprint reports "placed/total"; nothing is placed yet.
    expect(find.textContaining('0/'), findsOneWidget);

    final Finder blueprint = find.byKey(const ValueKey<String>('ark-build-area'));
    expect(blueprint, findsOneWidget);
    final Rect area = tester.getRect(blueprint);
    // Drop toward the RIGHT-HAND END of the keel, still well within its own
    // footprint. The old maths shifted the reading right by half the piece
    // width, which pushed exactly this drop out of range for a long beam.
    final Offset keelTarget = Offset(
      area.left + (keel.targetLeft + keel.width * 0.4) * area.width,
      area.top + keel.targetTop * area.height,
    );

    final Finder keelChip = find.widgetWithText(Container, keel.label).first;
    final TestGesture drag =
        await tester.startGesture(tester.getCenter(keelChip));
    await tester.pump(const Duration(milliseconds: 200));
    await drag.moveTo(keelTarget);
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1/'),
      findsOneWidget,
      reason: 'the keel should have snapped into place',
    );
  });
}
