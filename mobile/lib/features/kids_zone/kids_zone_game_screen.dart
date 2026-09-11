import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/local_store.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../widgets/state_views.dart';
import 'games/animal_care_game.dart';
import 'games/animal_matching_game.dart';
import 'games/archery_game.dart';
import 'games/ark_builder_game.dart';
import 'games/battle_intro_game.dart';
import 'games/creation_intro_game.dart';
import 'games/noah_intro_game.dart';
import 'games/connect_creations_game.dart';
import 'games/jumbled_words_game.dart';
import 'games/listen_and_answer_game.dart';
import 'games/explorer_game.dart';
import 'games/match_pairs_game.dart';
import 'games/moses_intro_game.dart';
import 'games/plague_sort_game.dart';
import 'games/sea_crossing_game.dart';
import 'games/river_rescue_game.dart';
import 'games/story_path_game.dart';
import 'games/trail_order_game.dart';
import 'kids_zone_adventures.dart';
import 'kids_zone_game_catalog.dart';

/// Routes to the correct Kids Zone mini-game for an adventure stop.
class KidsZoneGameScreen extends StatefulWidget {
  const KidsZoneGameScreen({super.key, required this.args});

  final KidsZoneGameplayArgs args;

  @override
  State<KidsZoneGameScreen> createState() => _KidsZoneGameScreenState();
}

class _KidsZoneGameScreenState extends State<KidsZoneGameScreen> {
  KidsZoneGameplayArgs get args => widget.args;

  /// Children double-tap. Every game's "finish" button was a plain
  /// `onPressed: onFinish` with nothing to stop a second tap landing inside the
  /// await below, which sent the stop through twice: two
  /// `kids_zone_stop_completed` events for one completion, and two
  /// `pushReplacementNamed` calls. One flag here covers all eighteen games,
  /// which is why it lives at the router rather than in each of them.
  bool _completing = false;

  Future<void> _complete(BuildContext context, int stars) async {
    if (_completing) return;
    _completing = true;

    final LocalStore store = context.read<LocalStore>();
    final AnalyticsService analytics = context.read<AnalyticsService>();
    final NavigatorState navigator = Navigator.of(context);
    await store.markKidsZoneStopComplete(args.stopId, stars: stars);
    if (!context.mounted) return;

    analytics.track(
      'kids_zone_stop_completed',
      properties: <String, Object?>{
        'adventure_id': args.adventureId,
        'stop_id': args.stopId,
        'stars': stars,
      },
    );

    final KidsAdventure? adventure = kidsZoneAdventureById(args.adventureId);
    String? nextStopId;
    if (adventure != null) {
      final int idx = adventure.stops.indexWhere((KidsAdventureStop s) => s.id == args.stopId);
      if (idx >= 0 && idx + 1 < adventure.stops.length) {
        nextStopId = adventure.stops[idx + 1].id;
      }
    }

    navigator.pushReplacementNamed(
      Routes.kidsZoneComplete,
      arguments: KidsZoneCompleteArgs(
        adventureId: args.adventureId,
        stopId: args.stopId,
        stopTitle: args.stopTitle,
        stars: stars,
        nextStopId: nextStopId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final KidsZoneGameDefinition? game = kidsZoneGameForStop(args.stopId);

    if (game == null) {
      return Scaffold(
        appBar: AppBar(title: Text(args.stopTitle)),
        body: EmptyView(
          message: l10n.kidsZoneGameMissing,
          icon: Icons.extension_off_rounded,
          actionLabel: l10n.actionClose,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    void onComplete(int stars) => _complete(context, stars);

    return switch (game.kind) {
      KidsZoneGameKind.creationIntro => CreationIntroGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.battleIntro => BattleIntroGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.archery => ArcheryGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.noahIntro => NoahIntroGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.arkBuilder => ArkBuilderGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.animalMatching => AnimalMatchingGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.animalCare => AnimalCareGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.mosesIntro => MosesIntroGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.seaCrossing => SeaCrossingGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.plagueSort => PlagueSortGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.riverRescue => RiverRescueGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.listenAndAnswer => ListenAndAnswerGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.connectCreations => ConnectCreationsGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.jumbledWords => JumbledWordsGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.storyPath => StoryPathGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.matchPairs => MatchPairsGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.trailOrder => TrailOrderGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
      KidsZoneGameKind.explorer => ExplorerGame(
          definition: game,
          stopTitle: args.stopTitle,
          adventureTitle: args.adventureTitle,
          onComplete: onComplete,
        ),
    };
  }
}
