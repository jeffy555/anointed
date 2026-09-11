import 'package:flutter/material.dart';

import 'levels/genesis_creation_level.dart';
import 'levels/moses_exodus_level.dart';
import 'levels/noah_ark_level.dart';
import 'levels/siddim_battle_level.dart';

export 'levels/genesis_creation_level.dart'
    show
        CreationCelebration,
        CreationDayIntro,
        DayCreationPair,
        JumbledSentence,
        ListeningQuestion,
        StoryListenPart,
        kGenesisLevel1OptionRamp;

export 'levels/siddim_battle_level.dart'
    show
        ArcheryWave,
        BattleIntroScene,
        BattleVisualLayer,
        SiddimColors;

export 'levels/noah_ark_level.dart'
    show
        ArkAnimalPair,
        ArkBuildStage,
        ArkCareNeed,
        ArkCareRound,
        ArkColors,
        ArkIntroScene,
        ArkPiece,
        ArkPieceShape,
        ArkStall,
        ArkVisualLayer,
        ArkWeather;

export 'levels/moses_exodus_level.dart'
    show
        AngelBlessing,
        MosesColors,
        MosesEra,
        MosesIntroScene,
        MosesFigure,
        MosesFigureKind,
        ChariotWave,
        PlagueCard,
        PlagueEffect,
        PlagueRound,
        SeaBeat,
        SeaBeatKind,
        SeaPhase,
        SeaClosingSequence,
        SeaClosingStage,
        SeaStage,
        RiverLane,
        RiverLotus,
        RiverObstacleKind,
        RiverResponse,
        RiverSpawn,
        RiverStage,
        kMosesIntroScenes,
        kMosesChariots,
        kMosesPlagueRounds,
        kMosesSeaPhases,
        kSeaScoredBeats,
        seaCrossingStars,
        kMosesPlagues,
        kPharaohResolveCracks,
        kPlaguePreviewDefaultAge,
        kPlagueStreakGlow,
        plagueSortStars,
        kRiverBlessingSeconds,
        kRiverBoostFactor,
        kRiverBoostSeconds,
        kRiverStartingHearts,
        riverRescueStars;

/// Types of Kids Zone activities — Creation Garden uses intro + 3 levels.
enum KidsZoneGameKind {
  creationIntro,
  battleIntro,
  archery,
  noahIntro,
  arkBuilder,
  animalMatching,
  animalCare,
  mosesIntro,
  riverRescue,
  plagueSort,
  seaCrossing,
  listenAndAnswer,
  connectCreations,
  jumbledWords,
  storyPath,
  matchPairs,
  trailOrder,
  explorer,
}

// StoryListenPart and ListeningQuestion are defined in genesis_creation_level.dart.

class StoryScene {
  const StoryScene({
    required this.narration,
    required this.icon,
    required this.iconColor,
    this.choices = const <StoryChoice>[],
  });

  final String narration;
  final IconData icon;
  final Color iconColor;

  /// Empty choices means tap Continue to advance.
  final List<StoryChoice> choices;
}

class StoryChoice {
  const StoryChoice({required this.label, required this.response, required this.nextSceneIndex});

  final String label;
  final String response;
  final int nextSceneIndex;
}

class MatchPairCard {
  const MatchPairCard({required this.id, required this.label, required this.icon, required this.color});

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class TrailStep {
  const TrailStep({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

class ExplorerTarget {
  const ExplorerTarget({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.leftFraction,
    required this.topFraction,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final double leftFraction;
  final double topFraction;
}

class KidsZoneGameDefinition {
  const KidsZoneGameDefinition({
    required this.stopId,
    required this.kind,
    required this.intro,
    this.introDays = const <CreationDayIntro>[],
    this.storyParts = const <StoryListenPart>[],
    this.listeningQuestions = const <ListeningQuestion>[],
    this.dayCreations = const <DayCreationPair>[],
    this.creationDistractors = const <DayCreationPair>[],
    this.jumbledSentences = const <JumbledSentence>[],
    this.battleScenes = const <BattleIntroScene>[],
    this.archeryWaves = const <ArcheryWave>[],
    this.arkScenes = const <ArkIntroScene>[],
    this.arkStages = const <ArkBuildStage>[],
    this.arkAnimals = const <ArkAnimalPair>[],
    this.arkCareRounds = const <ArkCareRound>[],
    this.mosesScenes = const <MosesIntroScene>[],
    this.riverStages = const <RiverStage>[],
    this.plagueRounds = const <PlagueRound>[],
    this.seaPhases = const <SeaPhase>[],
    this.storyScenes = const <StoryScene>[],
    this.matchCards = const <MatchPairCard>[],
    this.trailSteps = const <TrailStep>[],
    this.explorerSceneTitle = '',
    this.explorerTargets = const <ExplorerTarget>[],
  });

  final String stopId;
  final KidsZoneGameKind kind;
  final String intro;
  final List<CreationDayIntro> introDays;
  final List<StoryListenPart> storyParts;
  final List<ListeningQuestion> listeningQuestions;
  final List<DayCreationPair> dayCreations;

  /// Wrong answers mixed into the connect board — things God did not make in
  /// the creation week.
  final List<DayCreationPair> creationDistractors;
  final List<JumbledSentence> jumbledSentences;
  final List<BattleIntroScene> battleScenes;
  final List<ArcheryWave> archeryWaves;
  final List<ArkIntroScene> arkScenes;
  final List<ArkBuildStage> arkStages;
  final List<ArkAnimalPair> arkAnimals;
  final List<ArkCareRound> arkCareRounds;

  /// The narrated beats of the Baby Moses introduction.
  final List<MosesIntroScene> mosesScenes;

  /// River Rescue's three stretches of the Nile.
  final List<RiverStage> riverStages;

  /// Plague Sort's three rounds.
  final List<PlagueRound> plagueRounds;

  /// Sea Crossing's four phases.
  final List<SeaPhase> seaPhases;
  final List<StoryScene> storyScenes;
  final List<MatchPairCard> matchCards;
  final List<TrailStep> trailSteps;
  final String explorerSceneTitle;
  final List<ExplorerTarget> explorerTargets;
}

const Map<String, KidsZoneGameDefinition> kKidsZoneGames = <String, KidsZoneGameDefinition>{
  'creation_intro': KidsZoneGameDefinition(
    stopId: 'creation_intro',
    kind: KidsZoneGameKind.creationIntro,
    intro: 'Watch and listen as God creates the world, day by day.',
    introDays: kGenesisIntroDays,
  ),
  'garden_1': KidsZoneGameDefinition(
    stopId: 'garden_1',
    kind: KidsZoneGameKind.listenAndAnswer,
    intro: 'Level 1 — Answer God\'s questions about Creation.',
    listeningQuestions: kGenesisLevel1Questions,
  ),
  'garden_2': KidsZoneGameDefinition(
    stopId: 'garden_2',
    kind: KidsZoneGameKind.connectCreations,
    intro: 'Level 2 — Connect each day to what God created.',
    dayCreations: kGenesisDayCreations,
    creationDistractors: kGenesisCreationDistractors,
  ),
  'garden_3': KidsZoneGameDefinition(
    stopId: 'garden_3',
    kind: KidsZoneGameKind.jumbledWords,
    intro: 'Level 3 — Unscramble the creation sentences.',
    jumbledSentences: kGenesisJumbledSentences,
  ),
  'siddim_intro': KidsZoneGameDefinition(
    stopId: 'siddim_intro',
    kind: KidsZoneGameKind.battleIntro,
    intro: 'Hear how Abram rescued Lot from four powerful kings.',
    battleScenes: kSiddimIntroScenes,
  ),
  'siddim_1': KidsZoneGameDefinition(
    stopId: 'siddim_1',
    kind: KidsZoneGameKind.archery,
    intro: 'Level 1 — Rounds 1 and 2. Drag to aim, release to shoot!',
    archeryWaves: kSiddimLevel1Waves,
  ),
  'siddim_2': KidsZoneGameDefinition(
    stopId: 'siddim_2',
    kind: KidsZoneGameKind.archery,
    intro: 'Level 2 — Rounds 3 to 5. Faster soldiers, trickier weaving.',
    archeryWaves: kSiddimLevel2Waves,
  ),
  'siddim_3': KidsZoneGameDefinition(
    stopId: 'siddim_3',
    kind: KidsZoneGameKind.archery,
    intro: 'Level 3 — The King\'s Round. Only your most careful arrows will do.',
    archeryWaves: kSiddimKingWaves,
  ),
  'ark_intro': KidsZoneGameDefinition(
    stopId: 'ark_intro',
    kind: KidsZoneGameKind.noahIntro,
    intro: 'Hear how Noah obeyed God and built the ark.',
    arkScenes: kArkIntroScenes,
  ),
  'ark_1': KidsZoneGameDefinition(
    stopId: 'ark_1',
    kind: KidsZoneGameKind.arkBuilder,
    intro: 'Level 1 — Build the ark, one piece of timber at a time.',
    arkStages: kArkBuildStages,
  ),
  'ark_2': KidsZoneGameDefinition(
    stopId: 'ark_2',
    kind: KidsZoneGameKind.animalMatching,
    intro: 'Level 2 — Find every animal and its mate, two by two.',
    arkAnimals: kArkAnimalPairs,
  ),
  'ark_3': KidsZoneGameDefinition(
    stopId: 'ark_3',
    kind: KidsZoneGameKind.animalCare,
    intro: 'Level 3 — Feed, water, clean and comfort the animals on board.',
    arkCareRounds: kArkCareRounds,
  ),
  'moses_intro': KidsZoneGameDefinition(
    stopId: 'moses_intro',
    kind: KidsZoneGameKind.mosesIntro,
    intro: 'Hear how God kept baby Moses safe on the river.',
    mosesScenes: kMosesIntroScenes,
  ),
  'moses_1': KidsZoneGameDefinition(
    stopId: 'moses_1',
    kind: KidsZoneGameKind.riverRescue,
    intro: 'Level 1 — Steer baby Moses down the Nile to the princess.',
    riverStages: kMosesRiverStages,
  ),
  'moses_2': KidsZoneGameDefinition(
    stopId: 'moses_2',
    kind: KidsZoneGameKind.plagueSort,
    intro: 'Level 2 — Put the ten plagues in the order they happened.',
    plagueRounds: kMosesPlagueRounds,
  ),
  'moses_3': KidsZoneGameDefinition(
    stopId: 'moses_3',
    kind: KidsZoneGameKind.seaCrossing,
    intro: 'Level 3 — Part the sea, cross over, and turn the army back.',
    seaPhases: kMosesSeaPhases,
  ),
  'heroes_2': KidsZoneGameDefinition(
    stopId: 'heroes_2',
    kind: KidsZoneGameKind.explorer,
    intro: 'Explore the pasture and find everything young David needs!',
    explorerSceneTitle: 'David\'s Pasture',
    explorerTargets: <ExplorerTarget>[
      ExplorerTarget(
        id: 'sheep',
        label: 'Sheep',
        icon: Icons.grass_rounded,
        color: Color(0xFF81C784),
        leftFraction: 0.12,
        topFraction: 0.55,
      ),
      ExplorerTarget(
        id: 'sling',
        label: 'Sling',
        icon: Icons.sports_rounded,
        color: Color(0xFF8D6E63),
        leftFraction: 0.62,
        topFraction: 0.48,
      ),
      ExplorerTarget(
        id: 'harp',
        label: 'Harp',
        icon: Icons.music_note_rounded,
        color: Color(0xFF9575CD),
        leftFraction: 0.38,
        topFraction: 0.72,
      ),
      ExplorerTarget(
        id: 'courage',
        label: 'Courage',
        icon: Icons.favorite_rounded,
        color: Color(0xFFEF5350),
        leftFraction: 0.78,
        topFraction: 0.28,
      ),
    ],
  ),
  'kings_1': KidsZoneGameDefinition(
    stopId: 'kings_1',
    kind: KidsZoneGameKind.storyPath,
    intro: 'Help young Solomon choose the best gift from God!',
    storyScenes: <StoryScene>[
      StoryScene(
        narration: 'Solomon became king. God appeared in a dream and said, "Ask for anything you want."',
        icon: Icons.nightlight_round,
        iconColor: Color(0xFF5C6BC0),
      ),
      StoryScene(
        narration: 'What should Solomon ask for?',
        icon: Icons.help_rounded,
        iconColor: Color(0xFFFF9800),
        choices: <StoryChoice>[
          StoryChoice(
            label: 'Mountains of gold',
            response: 'Gold is shiny, but Solomon wanted something better…',
            nextSceneIndex: 2,
          ),
          StoryChoice(
            label: 'Wisdom to lead',
            response: 'Perfect! Solomon asked for wisdom to help God\'s people.',
            nextSceneIndex: 3,
          ),
          StoryChoice(
            label: 'A giant castle',
            response: 'A castle is cool, but Solomon wanted something better…',
            nextSceneIndex: 2,
          ),
        ],
      ),
      StoryScene(
        narration: 'Solomon thought again. "I need wisdom to care for everyone fairly."',
        icon: Icons.lightbulb_outline_rounded,
        iconColor: Color(0xFFFFB300),
        choices: <StoryChoice>[
          StoryChoice(
            label: 'Ask for wisdom',
            response: 'God smiled — wisdom was the best gift!',
            nextSceneIndex: 3,
          ),
        ],
      ),
      StoryScene(
        narration: 'God gave Solomon great wisdom. He became the wisest king ever!',
        icon: Icons.auto_stories_rounded,
        iconColor: Color(0xFFFF9800),
      ),
    ],
  ),
};

KidsZoneGameDefinition? kidsZoneGameForStop(String stopId) => kKidsZoneGames[stopId];
