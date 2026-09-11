import 'package:flutter/material.dart';

/// Noah's Ark (Genesis 6–9) — intro narration plus three level datasets.
///
/// Adventure shape matches Creation Garden and Battle of Siddim: a narrated
/// introduction followed by three playable levels —
/// 1. Ark Builder puzzle (obedience / patience)
/// 2. Animal Matching memory game (God saves the animals two by two)
/// 3. Animal Care simulation (responsibility / stewardship)

/// Palette for the Ark world — warm timber against rain-washed sky.
class ArkColors {
  const ArkColors._();

  static const Color skyTop = Color(0xFF6B8FB5);
  static const Color skyMid = Color(0xFF9DBBD4);
  static const Color skyLow = Color(0xFFDCE9F2);
  static const Color water = Color(0xFF3D6E8F);
  static const Color waterDeep = Color(0xFF23485F);
  static const Color timber = Color(0xFF8D6E4F);
  static const Color timberDark = Color(0xFF5D4632);
  static const Color timberLight = Color(0xFFB08963);
  static const Color pitch = Color(0xFF4E342E);
  static const Color blueprint = Color(0xFFB3E5FC);
  static const Color straw = Color(0xFFE8C77A);
  static const Color leaf = Color(0xFF7CB342);
  static const Color dove = Color(0xFFFFFDF7);
  static const Color heart = Color(0xFFEF5350);
  static const Color ink = Color(0xFF1A3A52);

  static LinearGradient get skyGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[skyTop, skyMid, skyLow],
        stops: <double>[0.0, 0.55, 1.0],
      );
}

/// Weather/backdrop mood for an introduction beat.
enum ArkWeather { calm, building, gathering, rain, flood, dove, rainbow }

/// A layered figure painted onto the Ark backdrop during the intro.
class ArkVisualLayer {
  const ArkVisualLayer({
    required this.icon,
    required this.color,
    required this.top,
    required this.left,
    required this.size,
  });

  final IconData icon;
  final Color color;

  /// Fractions of the backdrop height / width.
  final double top;
  final double left;
  final double size;
}

/// One narrated beat of the Noah story.
class ArkIntroScene {
  const ArkIntroScene({
    required this.sceneLabel,
    required this.narration,
    required this.weather,
    this.visualLayers = const <ArkVisualLayer>[],
  });

  final String sceneLabel;
  final String narration;
  final ArkWeather weather;
  final List<ArkVisualLayer> visualLayers;
}

// ---------------------------------------------------------------- Level 1

/// How a build piece is drawn — plain timber, or a detailed fitting.
enum ArkPieceShape { beam, plank, rib, roof, door, window, ramp, mast }

/// A single draggable piece of the Ark, and where it belongs.
class ArkPiece {
  const ArkPiece({
    required this.id,
    required this.label,
    required this.shape,
    required this.targetLeft,
    required this.targetTop,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  final String id;
  final String label;
  final ArkPieceShape shape;

  /// Centre of the finished position, as fractions of the build area.
  final double targetLeft;
  final double targetTop;

  /// Size as fractions of the build area.
  final double width;
  final double height;

  /// Radians.
  final double rotation;
}

/// One build stage — pieces get smaller and more numerous as stages progress.
class ArkBuildStage {
  const ArkBuildStage({
    required this.stage,
    required this.title,
    required this.cue,
    required this.pieces,
  });

  final int stage;
  final String title;
  final String cue;
  final List<ArkPiece> pieces;
}

// ---------------------------------------------------------------- Level 2

/// One animal that boards the Ark as a male/female pair.
class ArkAnimalPair {
  const ArkAnimalPair({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String label;

  /// Rendered with the platform emoji font, so the card shows a real colour
  /// picture of the animal rather than an approximate glyph.
  final String emoji;
  final Color color;
}

// ---------------------------------------------------------------- Level 3

/// What an animal is asking for in the care simulation.
enum ArkCareNeed { food, water, clean, comfort }

/// A stall aboard the Ark, holding one kind of animal.
class ArkStall {
  const ArkStall({
    required this.id,
    required this.animalLabel,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String animalLabel;
  final String emoji;
  final Color color;
}

/// One care round — more stalls and quicker needs as rounds progress.
class ArkCareRound {
  const ArkCareRound({
    required this.round,
    required this.title,
    required this.cue,
    required this.stalls,
    required this.tasksToComplete,
    required this.spawnInterval,
    required this.patienceSeconds,
  });

  final int round;
  final String title;
  final String cue;
  final List<ArkStall> stalls;

  /// How many needs must be met to finish the round.
  final int tasksToComplete;

  /// Seconds between new needs appearing.
  final double spawnInterval;

  /// Seconds an animal waits before its happiness drops.
  final double patienceSeconds;
}

// ================================================================ CONTENT

/// Introduction — Genesis 6–9 in nine child-friendly beats.
const List<ArkIntroScene> kArkIntroScenes = <ArkIntroScene>[
  ArkIntroScene(
    sceneLabel: 'A world gone wrong',
    narration:
        'Long ago the world was full of people who had forgotten God. '
        'But there was one man who still walked with God, and his name was Noah.',
    weather: ArkWeather.calm,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.person_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.52,
        left: 0.46,
        size: 52,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'God speaks to Noah',
    narration:
        'God said to Noah, "Build a great boat — an ark. '
        'I will send a flood, but I will keep you and your family safe."',
    weather: ArkWeather.calm,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.auto_awesome_rounded,
        color: Color(0xFFFFF176),
        top: 0.18,
        left: 0.44,
        size: 56,
      ),
      ArkVisualLayer(
        icon: Icons.person_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.52,
        left: 0.46,
        size: 52,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'The plan',
    narration:
        'God told Noah exactly how to build it — three hundred cubits long, '
        'fifty wide, and thirty high, with rooms inside and one door on the side.',
    weather: ArkWeather.building,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.straighten_rounded,
        color: ArkColors.blueprint,
        top: 0.30,
        left: 0.24,
        size: 50,
      ),
      ArkVisualLayer(
        icon: Icons.architecture_rounded,
        color: ArkColors.blueprint,
        top: 0.38,
        left: 0.62,
        size: 50,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'Years of hammering',
    narration:
        'Noah worked for many, many years. People laughed at him and asked why '
        'he was building a boat on dry land. Noah kept building, because God had said so.',
    weather: ArkWeather.building,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.handyman_rounded,
        color: ArkColors.timberLight,
        top: 0.34,
        left: 0.30,
        size: 52,
      ),
      ArkVisualLayer(
        icon: Icons.directions_boat_rounded,
        color: ArkColors.timber,
        top: 0.48,
        left: 0.56,
        size: 62,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'Two by two',
    narration:
        'Then the animals came — two by two, a male and a female of every kind. '
        'They walked into the ark, and Noah\'s family went in too.',
    weather: ArkWeather.gathering,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.pets_rounded,
        color: Color(0xFF8D6E63),
        top: 0.56,
        left: 0.22,
        size: 46,
      ),
      ArkVisualLayer(
        icon: Icons.pets_rounded,
        color: Color(0xFFA1887F),
        top: 0.60,
        left: 0.36,
        size: 40,
      ),
      ArkVisualLayer(
        icon: Icons.directions_boat_rounded,
        color: ArkColors.timber,
        top: 0.42,
        left: 0.60,
        size: 66,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'God shuts the door',
    narration:
        'When everyone was safely inside, God himself shut the door. '
        'Then the rain began to fall.',
    weather: ArkWeather.rain,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.door_front_door_rounded,
        color: ArkColors.timberDark,
        top: 0.46,
        left: 0.46,
        size: 52,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'Forty days',
    narration:
        'It rained for forty days and forty nights. The waters lifted the ark high above '
        'the hills, but inside, Noah and every animal were safe.',
    weather: ArkWeather.flood,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.directions_boat_rounded,
        color: ArkColors.timber,
        top: 0.40,
        left: 0.42,
        size: 72,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'The dove returns',
    narration:
        'Noah sent out a dove. It came back carrying a fresh olive leaf — '
        'the water was going down, and dry land was waiting.',
    weather: ArkWeather.dove,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.flutter_dash_rounded,
        color: ArkColors.dove,
        top: 0.26,
        left: 0.50,
        size: 54,
      ),
      ArkVisualLayer(
        icon: Icons.eco_rounded,
        color: ArkColors.leaf,
        top: 0.36,
        left: 0.36,
        size: 40,
      ),
    ],
  ),
  ArkIntroScene(
    sceneLabel: 'The rainbow promise',
    narration:
        'Everyone came out onto fresh, clean ground. God set a rainbow in the sky and promised '
        'never again to flood the whole earth. Now it is your turn to help Noah!',
    weather: ArkWeather.rainbow,
    visualLayers: <ArkVisualLayer>[
      ArkVisualLayer(
        icon: Icons.family_restroom_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.56,
        left: 0.28,
        size: 52,
      ),
      ArkVisualLayer(
        icon: Icons.pets_rounded,
        color: Color(0xFF8D6E63),
        top: 0.60,
        left: 0.62,
        size: 44,
      ),
    ],
  ),
];

/// Level 1 — three build stages, from big beams to the finishing details.
/// Level 1 — four build stages: keel, hull, decks, then the fittings.
///
/// Twenty-four pieces in all, escalating from a few heavy beams to the small
/// doors, windows and mast, so the Ark visibly grows the way Noah's did.
const List<ArkBuildStage> kArkBuildStages = <ArkBuildStage>[
  ArkBuildStage(
    stage: 1,
    title: 'The keel',
    cue: 'Lay the backbone of the ark. Drag each beam onto its glowing outline.',
    pieces: <ArkPiece>[
      ArkPiece(
        id: 'keel',
        label: 'Keel beam',
        shape: ArkPieceShape.beam,
        targetLeft: 0.50,
        targetTop: 0.76,
        width: 0.62,
        height: 0.070,
      ),
      ArkPiece(
        id: 'bow',
        label: 'Bow post',
        shape: ArkPieceShape.beam,
        targetLeft: 0.19,
        targetTop: 0.67,
        width: 0.17,
        height: 0.060,
        rotation: -0.55,
      ),
      ArkPiece(
        id: 'stern',
        label: 'Stern post',
        shape: ArkPieceShape.beam,
        targetLeft: 0.81,
        targetTop: 0.67,
        width: 0.17,
        height: 0.060,
        rotation: 0.55,
      ),
      ArkPiece(
        id: 'cross_left',
        label: 'Cross beam',
        shape: ArkPieceShape.rib,
        targetLeft: 0.35,
        targetTop: 0.705,
        width: 0.048,
        height: 0.085,
      ),
      ArkPiece(
        id: 'cross_right',
        label: 'Cross beam',
        shape: ArkPieceShape.rib,
        targetLeft: 0.65,
        targetTop: 0.705,
        width: 0.048,
        height: 0.085,
      ),
    ],
  ),
  ArkBuildStage(
    stage: 2,
    title: 'Hull and ribs',
    cue: 'Now the walls of gopher wood. Line the long planks along the hull.',
    pieces: <ArkPiece>[
      ArkPiece(
        id: 'hull_low',
        label: 'Lower plank',
        shape: ArkPieceShape.plank,
        targetLeft: 0.50,
        targetTop: 0.685,
        width: 0.66,
        height: 0.048,
      ),
      ArkPiece(
        id: 'hull_mid',
        label: 'Middle plank',
        shape: ArkPieceShape.plank,
        targetLeft: 0.50,
        targetTop: 0.625,
        width: 0.70,
        height: 0.048,
      ),
      ArkPiece(
        id: 'hull_high',
        label: 'Upper plank',
        shape: ArkPieceShape.plank,
        targetLeft: 0.50,
        targetTop: 0.565,
        width: 0.72,
        height: 0.048,
      ),
      ArkPiece(
        id: 'rib_left',
        label: 'Left rib',
        shape: ArkPieceShape.rib,
        targetLeft: 0.24,
        targetTop: 0.625,
        width: 0.042,
        height: 0.140,
      ),
      ArkPiece(
        id: 'rib_mid',
        label: 'Centre rib',
        shape: ArkPieceShape.rib,
        targetLeft: 0.50,
        targetTop: 0.625,
        width: 0.042,
        height: 0.140,
      ),
      ArkPiece(
        id: 'rib_right',
        label: 'Right rib',
        shape: ArkPieceShape.rib,
        targetLeft: 0.76,
        targetTop: 0.625,
        width: 0.042,
        height: 0.140,
      ),
    ],
  ),
  ArkBuildStage(
    stage: 3,
    title: 'Decks and cabin',
    cue: 'God said to make rooms inside. Add the decks and the cabin walls.',
    pieces: <ArkPiece>[
      ArkPiece(
        id: 'deck',
        label: 'Main deck',
        shape: ArkPieceShape.plank,
        targetLeft: 0.50,
        targetTop: 0.505,
        width: 0.72,
        height: 0.042,
      ),
      ArkPiece(
        id: 'wall_left',
        label: 'Left wall',
        shape: ArkPieceShape.rib,
        targetLeft: 0.30,
        targetTop: 0.425,
        width: 0.048,
        height: 0.120,
      ),
      ArkPiece(
        id: 'wall_mid',
        label: 'Middle wall',
        shape: ArkPieceShape.rib,
        targetLeft: 0.50,
        targetTop: 0.425,
        width: 0.048,
        height: 0.120,
      ),
      ArkPiece(
        id: 'wall_right',
        label: 'Right wall',
        shape: ArkPieceShape.rib,
        targetLeft: 0.70,
        targetTop: 0.425,
        width: 0.048,
        height: 0.120,
      ),
      ArkPiece(
        id: 'upper_deck',
        label: 'Upper deck',
        shape: ArkPieceShape.plank,
        targetLeft: 0.50,
        targetTop: 0.355,
        width: 0.50,
        height: 0.038,
      ),
      ArkPiece(
        id: 'ramp',
        label: 'Boarding ramp',
        shape: ArkPieceShape.ramp,
        targetLeft: 0.20,
        targetTop: 0.800,
        width: 0.19,
        height: 0.040,
        rotation: 0.32,
      ),
    ],
  ),
  ArkBuildStage(
    stage: 4,
    title: 'Roof, doors and windows',
    cue: 'Last pieces! Fit the roof, the great door, the windows and the mast.',
    pieces: <ArkPiece>[
      ArkPiece(
        id: 'roof',
        label: 'Roof',
        shape: ArkPieceShape.roof,
        targetLeft: 0.50,
        targetTop: 0.295,
        width: 0.52,
        height: 0.058,
      ),
      ArkPiece(
        id: 'door',
        label: 'Great door',
        shape: ArkPieceShape.door,
        targetLeft: 0.385,
        targetTop: 0.445,
        width: 0.080,
        height: 0.095,
      ),
      ArkPiece(
        id: 'hatch',
        label: 'Side hatch',
        shape: ArkPieceShape.door,
        targetLeft: 0.615,
        targetTop: 0.445,
        width: 0.080,
        height: 0.095,
      ),
      ArkPiece(
        id: 'window_left',
        label: 'Left window',
        shape: ArkPieceShape.window,
        targetLeft: 0.365,
        targetTop: 0.360,
        width: 0.060,
        height: 0.046,
      ),
      ArkPiece(
        id: 'window_right',
        label: 'Right window',
        shape: ArkPieceShape.window,
        targetLeft: 0.635,
        targetTop: 0.360,
        width: 0.060,
        height: 0.046,
      ),
      ArkPiece(
        id: 'skylight',
        label: 'Skylight',
        shape: ArkPieceShape.window,
        targetLeft: 0.50,
        targetTop: 0.350,
        width: 0.060,
        height: 0.042,
      ),
      ArkPiece(
        id: 'mast',
        label: 'Mast',
        shape: ArkPieceShape.mast,
        targetLeft: 0.50,
        targetTop: 0.205,
        width: 0.034,
        height: 0.115,
      ),
    ],
  ),
];


/// Level 2 — ten animal kinds, each boarding as a male and a female.
const List<ArkAnimalPair> kArkAnimalPairs = <ArkAnimalPair>[
  ArkAnimalPair(
    id: 'lion',
    label: 'Lion',
    emoji: '🦁',
    color: Color(0xFFE9A13B),
  ),
  ArkAnimalPair(
    id: 'elephant',
    label: 'Elephant',
    emoji: '🐘',
    color: Color(0xFF90A4AE),
  ),
  ArkAnimalPair(
    id: 'giraffe',
    label: 'Giraffe',
    emoji: '🦒',
    color: Color(0xFFD4A257),
  ),
  ArkAnimalPair(
    id: 'sheep',
    label: 'Sheep',
    emoji: '🐑',
    color: Color(0xFFBDBDBD),
  ),
  ArkAnimalPair(
    id: 'rabbit',
    label: 'Rabbit',
    emoji: '🐰',
    color: Color(0xFFBCAAA4),
  ),
  ArkAnimalPair(
    id: 'dove',
    label: 'Dove',
    emoji: '🕊️',
    color: Color(0xFF81D4FA),
  ),
  ArkAnimalPair(
    id: 'turtle',
    label: 'Turtle',
    emoji: '🐢',
    color: Color(0xFF66BB6A),
  ),
  ArkAnimalPair(
    id: 'butterfly',
    label: 'Butterfly',
    emoji: '🦋',
    color: Color(0xFFBA68C8),
  ),
  ArkAnimalPair(
    id: 'bear',
    label: 'Bear',
    emoji: '🐻',
    color: Color(0xFF8D6E63),
  ),
  ArkAnimalPair(
    id: 'horse',
    label: 'Horse',
    emoji: '🐴',
    color: Color(0xFFA1887F),
  ),
];

/// Level 3 — three care rounds with a growing menagerie.
const List<ArkCareRound> kArkCareRounds = <ArkCareRound>[
  ArkCareRound(
    round: 1,
    title: 'Morning rounds',
    cue: 'Tap a tool, then tap the animal that needs it.',
    tasksToComplete: 6,
    spawnInterval: 3.4,
    patienceSeconds: 11,
    stalls: <ArkStall>[
      ArkStall(
        id: 'sheep',
        animalLabel: 'Sheep',
        emoji: '🐑',
        color: Color(0xFFE0E0E0),
      ),
      ArkStall(
        id: 'rabbit',
        animalLabel: 'Rabbit',
        emoji: '🐰',
        color: Color(0xFFBCAAA4),
      ),
      ArkStall(
        id: 'dove',
        animalLabel: 'Dove',
        emoji: '🕊️',
        color: Color(0xFF81D4FA),
      ),
      ArkStall(
        id: 'lion',
        animalLabel: 'Lion',
        emoji: '🦁',
        color: Color(0xFFE9A13B),
      ),
    ],
  ),
  ArkCareRound(
    round: 2,
    title: 'A busy deck',
    cue: 'More animals are awake now. Keep everyone happy!',
    tasksToComplete: 8,
    spawnInterval: 2.7,
    patienceSeconds: 9.5,
    stalls: <ArkStall>[
      ArkStall(
        id: 'sheep',
        animalLabel: 'Sheep',
        emoji: '🐑',
        color: Color(0xFFE0E0E0),
      ),
      ArkStall(
        id: 'rabbit',
        animalLabel: 'Rabbit',
        emoji: '🐰',
        color: Color(0xFFBCAAA4),
      ),
      ArkStall(
        id: 'dove',
        animalLabel: 'Dove',
        emoji: '🕊️',
        color: Color(0xFF81D4FA),
      ),
      ArkStall(
        id: 'lion',
        animalLabel: 'Lion',
        emoji: '🦁',
        color: Color(0xFFE9A13B),
      ),
      ArkStall(
        id: 'bear',
        animalLabel: 'Bear',
        emoji: '🐻',
        color: Color(0xFF8D6E63),
      ),
    ],
  ),
  ArkCareRound(
    round: 3,
    title: 'The long voyage',
    cue: 'The rain is loud tonight. Care for every animal on board!',
    tasksToComplete: 10,
    spawnInterval: 2.1,
    patienceSeconds: 8,
    stalls: <ArkStall>[
      ArkStall(
        id: 'sheep',
        animalLabel: 'Sheep',
        emoji: '🐑',
        color: Color(0xFFE0E0E0),
      ),
      ArkStall(
        id: 'rabbit',
        animalLabel: 'Rabbit',
        emoji: '🐰',
        color: Color(0xFFBCAAA4),
      ),
      ArkStall(
        id: 'dove',
        animalLabel: 'Dove',
        emoji: '🕊️',
        color: Color(0xFF81D4FA),
      ),
      ArkStall(
        id: 'lion',
        animalLabel: 'Lion',
        emoji: '🦁',
        color: Color(0xFFE9A13B),
      ),
      ArkStall(
        id: 'bear',
        animalLabel: 'Bear',
        emoji: '🐻',
        color: Color(0xFF8D6E63),
      ),
      ArkStall(
        id: 'elephant',
        animalLabel: 'Elephant',
        emoji: '🐘',
        color: Color(0xFF90A4AE),
      ),
    ],
  ),
];
