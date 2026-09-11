import 'package:flutter/material.dart';

import 'kids_zone_game_catalog.dart';

/// A single stop on a Kids Zone adventure path — each stop is a mini-game.
class KidsAdventureStop {
  const KidsAdventureStop({
    required this.id,
    required this.icon,
    required this.gameKind,
  });

  final String id;
  final IconData icon;
  final KidsZoneGameKind gameKind;
}

/// A themed world in Kids Zone — a different progression model from the 100-level map.
class KidsAdventure {
  const KidsAdventure({
    required this.id,
    required this.color,
    required this.icon,
    required this.stops,
  });

  final String id;
  final Color color;
  final IconData icon;
  final List<KidsAdventureStop> stops;
}

/// Static adventure catalog for the Kids Zone world.
const List<KidsAdventure> kKidsAdventures = <KidsAdventure>[
  KidsAdventure(
    id: 'creation_garden',
    color: Color(0xFF4CAF50),
    icon: Icons.park_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'creation_intro',
        icon: Icons.movie_filter_rounded,
        gameKind: KidsZoneGameKind.creationIntro,
      ),
      KidsAdventureStop(
        id: 'garden_1',
        icon: Icons.hearing_rounded,
        gameKind: KidsZoneGameKind.listenAndAnswer,
      ),
      KidsAdventureStop(
        id: 'garden_2',
        icon: Icons.device_hub_rounded,
        gameKind: KidsZoneGameKind.connectCreations,
      ),
      KidsAdventureStop(
        id: 'garden_3',
        icon: Icons.extension_rounded,
        gameKind: KidsZoneGameKind.jumbledWords,
      ),
    ],
  ),
  KidsAdventure(
    id: 'battle_of_siddim',
    color: Color(0xFFD84315),
    icon: Icons.sports_martial_arts_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'siddim_intro',
        icon: Icons.movie_filter_rounded,
        gameKind: KidsZoneGameKind.battleIntro,
      ),
      KidsAdventureStop(
        id: 'siddim_1',
        icon: Icons.my_location_rounded,
        gameKind: KidsZoneGameKind.archery,
      ),
      KidsAdventureStop(
        id: 'siddim_2',
        icon: Icons.speed_rounded,
        gameKind: KidsZoneGameKind.archery,
      ),
      KidsAdventureStop(
        id: 'siddim_3',
        icon: Icons.emoji_events_rounded,
        gameKind: KidsZoneGameKind.archery,
      ),
    ],
  ),
  KidsAdventure(
    id: 'noahs_ark',
    color: Color(0xFF00897B),
    icon: Icons.sailing_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'ark_intro',
        icon: Icons.movie_filter_rounded,
        gameKind: KidsZoneGameKind.noahIntro,
      ),
      KidsAdventureStop(
        id: 'ark_1',
        icon: Icons.handyman_rounded,
        gameKind: KidsZoneGameKind.arkBuilder,
      ),
      KidsAdventureStop(
        id: 'ark_2',
        icon: Icons.pets_rounded,
        gameKind: KidsZoneGameKind.animalMatching,
      ),
      KidsAdventureStop(
        id: 'ark_3',
        icon: Icons.volunteer_activism_rounded,
        gameKind: KidsZoneGameKind.animalCare,
      ),
    ],
  ),
  KidsAdventure(
    id: 'moses_nile',
    color: Color(0xFF2E8B8B),
    icon: Icons.kayaking_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'moses_intro',
        icon: Icons.movie_filter_rounded,
        gameKind: KidsZoneGameKind.mosesIntro,
      ),
      KidsAdventureStop(
        id: 'moses_1',
        icon: Icons.kayaking_rounded,
        gameKind: KidsZoneGameKind.riverRescue,
      ),
      KidsAdventureStop(
        id: 'moses_2',
        icon: Icons.format_list_numbered_rounded,
        gameKind: KidsZoneGameKind.plagueSort,
      ),
      KidsAdventureStop(
        id: 'moses_3',
        icon: Icons.waves_rounded,
        gameKind: KidsZoneGameKind.seaCrossing,
      ),
    ],
  ),
  KidsAdventure(
    id: 'heroes_path',
    color: Color(0xFF2196F3),
    icon: Icons.shield_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'heroes_2',
        icon: Icons.music_note_rounded,
        gameKind: KidsZoneGameKind.explorer,
      ),
    ],
  ),
  KidsAdventure(
    id: 'wise_kings',
    color: Color(0xFFFF9800),
    icon: Icons.auto_stories_rounded,
    stops: <KidsAdventureStop>[
      KidsAdventureStop(
        id: 'kings_1',
        icon: Icons.lightbulb_rounded,
        gameKind: KidsZoneGameKind.storyPath,
      ),
    ],
  ),
];

KidsAdventureStop? kidsZoneStopById(String stopId) {
  for (final KidsAdventure adventure in kKidsAdventures) {
    for (final KidsAdventureStop stop in adventure.stops) {
      if (stop.id == stopId) return stop;
    }
  }
  return null;
}

KidsAdventure? kidsZoneAdventureById(String adventureId) {
  for (final KidsAdventure adventure in kKidsAdventures) {
    if (adventure.id == adventureId) return adventure;
  }
  return null;
}
