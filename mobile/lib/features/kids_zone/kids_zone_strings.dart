import '../../l10n/gen/app_localizations.dart';

// The adventure catalogue holds structure — ids, order, colour, which game a
// stop runs. Everything a player reads lives in the ARB and is resolved here.
//
// Kept as switches rather than a generated map because the generated
// localisations have no by-name accessor: `l10n.kidsZoneStopArk1Title` is a
// real getter and a typo is a compile error, where a string key would only fail
// at runtime. The same reason `plagueNarration` is written this way.

/// The adventure's name, as shown on the hub card.
///
/// Returns an empty string for an id the ARB does not cover, which
/// `kids_zone_strings_test.dart` asserts never happens for anything in the
/// catalogue. A switch on the id rather than a map lookup so the reader can
/// see every case, and so a stale id is visible rather than silently blank.
String kidsZoneAdventureTitle(AppLocalizations l10n, String id) {
  return switch (id) {
    'creation_garden' => l10n.kidsZoneAdventureCreationGardenTitle,
    'battle_of_siddim' => l10n.kidsZoneAdventureBattleOfSiddimTitle,
    'noahs_ark' => l10n.kidsZoneAdventureNoahsArkTitle,
    'moses_nile' => l10n.kidsZoneAdventureMosesNileTitle,
    'heroes_path' => l10n.kidsZoneAdventureHeroesPathTitle,
    'wise_kings' => l10n.kidsZoneAdventureWiseKingsTitle,
    _ => '',
  };
}

/// The line under an adventure's name.
///
/// Returns an empty string for an id the ARB does not cover, which
/// `kids_zone_strings_test.dart` asserts never happens for anything in the
/// catalogue. A switch on the id rather than a map lookup so the reader can
/// see every case, and so a stale id is visible rather than silently blank.
String kidsZoneAdventureSubtitle(AppLocalizations l10n, String id) {
  return switch (id) {
    'creation_garden' => l10n.kidsZoneAdventureCreationGardenSubtitle,
    'battle_of_siddim' => l10n.kidsZoneAdventureBattleOfSiddimSubtitle,
    'noahs_ark' => l10n.kidsZoneAdventureNoahsArkSubtitle,
    'moses_nile' => l10n.kidsZoneAdventureMosesNileSubtitle,
    'heroes_path' => l10n.kidsZoneAdventureHeroesPathSubtitle,
    'wise_kings' => l10n.kidsZoneAdventureWiseKingsSubtitle,
    _ => '',
  };
}

/// A stop's name, as shown on its row and in the game chrome.
///
/// Returns an empty string for an id the ARB does not cover, which
/// `kids_zone_strings_test.dart` asserts never happens for anything in the
/// catalogue. A switch on the id rather than a map lookup so the reader can
/// see every case, and so a stale id is visible rather than silently blank.
String kidsZoneStopTitle(AppLocalizations l10n, String id) {
  return switch (id) {
    'creation_intro' => l10n.kidsZoneStopCreationIntroTitle,
    'garden_1' => l10n.kidsZoneStopGarden1Title,
    'garden_2' => l10n.kidsZoneStopGarden2Title,
    'garden_3' => l10n.kidsZoneStopGarden3Title,
    'siddim_intro' => l10n.kidsZoneStopSiddimIntroTitle,
    'siddim_1' => l10n.kidsZoneStopSiddim1Title,
    'siddim_2' => l10n.kidsZoneStopSiddim2Title,
    'siddim_3' => l10n.kidsZoneStopSiddim3Title,
    'ark_intro' => l10n.kidsZoneStopArkIntroTitle,
    'ark_1' => l10n.kidsZoneStopArk1Title,
    'ark_2' => l10n.kidsZoneStopArk2Title,
    'ark_3' => l10n.kidsZoneStopArk3Title,
    'moses_intro' => l10n.kidsZoneStopMosesIntroTitle,
    'moses_1' => l10n.kidsZoneStopMoses1Title,
    'moses_2' => l10n.kidsZoneStopMoses2Title,
    'moses_3' => l10n.kidsZoneStopMoses3Title,
    'heroes_2' => l10n.kidsZoneStopHeroes2Title,
    'kings_1' => l10n.kidsZoneStopKings1Title,
    _ => '',
  };
}

/// The line under a stop's name, before it is finished.
///
/// Returns an empty string for an id the ARB does not cover, which
/// `kids_zone_strings_test.dart` asserts never happens for anything in the
/// catalogue. A switch on the id rather than a map lookup so the reader can
/// see every case, and so a stale id is visible rather than silently blank.
String kidsZoneStopTeaser(AppLocalizations l10n, String id) {
  return switch (id) {
    'creation_intro' => l10n.kidsZoneStopCreationIntroTeaser,
    'garden_1' => l10n.kidsZoneStopGarden1Teaser,
    'garden_2' => l10n.kidsZoneStopGarden2Teaser,
    'garden_3' => l10n.kidsZoneStopGarden3Teaser,
    'siddim_intro' => l10n.kidsZoneStopSiddimIntroTeaser,
    'siddim_1' => l10n.kidsZoneStopSiddim1Teaser,
    'siddim_2' => l10n.kidsZoneStopSiddim2Teaser,
    'siddim_3' => l10n.kidsZoneStopSiddim3Teaser,
    'ark_intro' => l10n.kidsZoneStopArkIntroTeaser,
    'ark_1' => l10n.kidsZoneStopArk1Teaser,
    'ark_2' => l10n.kidsZoneStopArk2Teaser,
    'ark_3' => l10n.kidsZoneStopArk3Teaser,
    'moses_intro' => l10n.kidsZoneStopMosesIntroTeaser,
    'moses_1' => l10n.kidsZoneStopMoses1Teaser,
    'moses_2' => l10n.kidsZoneStopMoses2Teaser,
    'moses_3' => l10n.kidsZoneStopMoses3Teaser,
    'heroes_2' => l10n.kidsZoneStopHeroes2Teaser,
    'kings_1' => l10n.kidsZoneStopKings1Teaser,
    _ => '',
  };
}
