import 'package:flutter/material.dart';

/// Battle of Siddim (Genesis 14) — intro narration + archery round content.
///
/// The adventure mirrors Creation Garden's shape (intro + 3 levels) while
/// delivering the six escalating archery rounds of the design brief:
/// rounds 1–2 in Level 1, rounds 3–5 in Level 2, and the King's Round in
/// Level 3.

/// Palette for the Siddim valley — dusk over the Salt Sea, warmer and more
/// dramatic than the Creation Garden sky.
class SiddimColors {
  const SiddimColors._();

  static const Color duskTop = Color(0xFF3E2C63);
  static const Color duskMid = Color(0xFFC2557A);
  static const Color duskLow = Color(0xFFF29D5C);
  static const Color sand = Color(0xFFE8C79A);
  static const Color ridge = Color(0xFF6D4C41);
  static const Color ridgeFar = Color(0xFF8D6E63);
  static const Color banner = Color(0xFFD84315);
  static const Color bow = Color(0xFF8D6E63);
  static const Color bowString = Color(0xFFFFF3E0);
  static const Color arrow = Color(0xFFFFF8E1);
  static const Color arrowFletch = Color(0xFF29B6F6);
  static const Color soldier = Color(0xFF5E5B8C);
  static const Color soldierShield = Color(0xFFB0BEC5);
  static const Color king = Color(0xFF7B1FA2);
  static const Color kingCrown = Color(0xFFFFC107);
  static const Color courage = Color(0xFFEF5350);
  static const Color abraham = Color(0xFF4E342E);
  static const Color abrahamRobe = Color(0xFFFFF3E0);

  static LinearGradient get duskGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[duskTop, duskMid, duskLow],
        stops: <double>[0.0, 0.55, 1.0],
      );
}

/// One layered figure painted onto the battlefield backdrop during the intro.
class BattleVisualLayer {
  const BattleVisualLayer({
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

/// A narrated beat of the Genesis 14 story.
class BattleIntroScene {
  const BattleIntroScene({
    required this.sceneLabel,
    required this.narration,
    required this.visualLayers,
    this.marchingSoldiers = 0,
  });

  final String sceneLabel;
  final String narration;
  final List<BattleVisualLayer> visualLayers;

  /// How many silhouetted soldiers march across the ridge for this beat.
  final int marchingSoldiers;
}

/// Configuration for one archery round. Rounds escalate in speed, count, and
/// how small a target the child has to hit.
class ArcheryWave {
  const ArcheryWave({
    required this.round,
    required this.title,
    required this.cue,
    required this.soldierCount,
    required this.speed,
    required this.zigzagAmplitude,
    required this.zigzagPeriod,
    required this.hitRadius,
    required this.spawnInterval,
    this.interlude = '',
    this.hitsToTurnBack = 1,
    this.isKingRound = false,
  });

  /// 1–6, matching the design brief's level numbering.
  final int round;
  final String title;
  final String cue;

  /// How many soldiers must be turned back to clear the round.
  final int soldierCount;

  /// Screen widths crossed per second.
  final double speed;

  /// Zig-zag height as a fraction of the field, and seconds per full weave.
  final double zigzagAmplitude;
  final double zigzagPeriod;

  /// Hit radius as a fraction of the field's shorter side.
  final double hitRadius;

  /// Seconds between soldiers entering the valley.
  final double spawnInterval;

  /// A story beat spoken before this round starts, tying the mechanical
  /// escalation to the march on the valley. Empty for the opening round.
  final String interlude;

  /// King Chedorlaomer's shield takes several arrows.
  final int hitsToTurnBack;
  final bool isKingRound;
}

/// Introduction — Genesis 14 told in eight child-friendly beats.
const List<BattleIntroScene> kSiddimIntroScenes = <BattleIntroScene>[
  BattleIntroScene(
    sceneLabel: 'The Valley of Siddim',
    narration:
        'Long ago, four strong kings marched into the Valley of Siddim. '
        'Five smaller kings came out to meet them. The valley was full of tar pits, '
        'and the ground shook with the sound of marching feet.',
    marchingSoldiers: 3,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.terrain_rounded,
        color: SiddimColors.ridgeFar,
        top: 0.42,
        left: 0.08,
        size: 76,
      ),
      BattleVisualLayer(
        icon: Icons.flag_rounded,
        color: SiddimColors.banner,
        top: 0.30,
        left: 0.70,
        size: 46,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'Lot is taken',
    narration:
        'The four kings won the battle. They took food, treasure, and people from the city of Sodom. '
        'Among them was Lot — Abram\'s own nephew.',
    marchingSoldiers: 4,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.location_city_rounded,
        color: Color(0xFF8D6E63),
        top: 0.34,
        left: 0.12,
        size: 62,
      ),
      BattleVisualLayer(
        icon: Icons.person_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.48,
        left: 0.62,
        size: 44,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'A messenger runs',
    narration:
        'One man escaped and ran all the way to Abram\'s camp under the great trees of Mamre. '
        '"They have taken Lot!" he cried.',
    marchingSoldiers: 1,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.park_rounded,
        color: Color(0xFF66BB6A),
        top: 0.40,
        left: 0.14,
        size: 66,
      ),
      BattleVisualLayer(
        icon: Icons.directions_run_rounded,
        color: Color(0xFFFFF8E1),
        top: 0.52,
        left: 0.56,
        size: 48,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'Abram is brave',
    narration:
        'Abram did not hide. He gathered three hundred and eighteen trained helpers from his own household '
        'and set out to bring Lot home.',
    marchingSoldiers: 0,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.groups_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.46,
        left: 0.18,
        size: 64,
      ),
      BattleVisualLayer(
        icon: Icons.shield_moon_rounded,
        color: Color(0xFFFFD54F),
        top: 0.24,
        left: 0.66,
        size: 52,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'The long march',
    narration:
        'They travelled far to the north, all the way to Dan. '
        'Abram was tired, but he kept going, because Lot needed him.',
    marchingSoldiers: 2,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.nights_stay_rounded,
        color: Color(0xFFE1BEE7),
        top: 0.16,
        left: 0.14,
        size: 50,
      ),
      BattleVisualLayer(
        icon: Icons.terrain_rounded,
        color: SiddimColors.ridge,
        top: 0.40,
        left: 0.58,
        size: 78,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'The night rescue',
    narration:
        'In the dark of night, Abram\'s helpers surrounded the camp from every side. '
        'King Chedorlaomer\'s army turned around and fled.',
    marchingSoldiers: 5,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.local_fire_department_rounded,
        color: Color(0xFFFF8A65),
        top: 0.50,
        left: 0.22,
        size: 52,
      ),
      BattleVisualLayer(
        icon: Icons.flag_rounded,
        color: SiddimColors.banner,
        top: 0.34,
        left: 0.68,
        size: 44,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'Lot comes home',
    narration:
        'Abram brought back everything that had been taken — the food, the treasure, '
        'the people, and Lot his nephew. Everyone was safe.',
    marchingSoldiers: 0,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.favorite_rounded,
        color: Color(0xFFEC407A),
        top: 0.28,
        left: 0.28,
        size: 48,
      ),
      BattleVisualLayer(
        icon: Icons.groups_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.48,
        left: 0.58,
        size: 60,
      ),
    ],
  ),
  BattleIntroScene(
    sceneLabel: 'A blessing',
    narration:
        'Melchizedek, the priest-king of Salem, brought bread and drink and blessed Abram. '
        'Abram gave God a tenth of everything, and gave the rest away. '
        'Now it is your turn to help Abram defend the valley!',
    marchingSoldiers: 0,
    visualLayers: <BattleVisualLayer>[
      BattleVisualLayer(
        icon: Icons.auto_awesome_rounded,
        color: Color(0xFFFFF176),
        top: 0.20,
        left: 0.40,
        size: 58,
      ),
      BattleVisualLayer(
        icon: Icons.emoji_food_beverage_rounded,
        color: Color(0xFFFFE0B2),
        top: 0.48,
        left: 0.30,
        size: 46,
      ),
      BattleVisualLayer(
        icon: Icons.volunteer_activism_rounded,
        color: Color(0xFFA5D6A7),
        top: 0.50,
        left: 0.62,
        size: 46,
      ),
    ],
  ),
];

/// Level 1 — rounds 1 and 2. Slow soldiers, wide targets, gentle weave.
const List<ArcheryWave> kSiddimLevel1Waves = <ArcheryWave>[
  ArcheryWave(
    round: 1,
    title: 'Round 1 — First watch',
    cue: 'Drag to aim, let go to shoot. Turn back 5 soldiers!',
    soldierCount: 5,
    speed: 0.10,
    zigzagAmplitude: 0.04,
    zigzagPeriod: 3.2,
    hitRadius: 0.085,
    spawnInterval: 1.9,
  ),
  ArcheryWave(
    round: 2,
    interlude: 'Abram\'s men pushed forward through the valley.',
    title: 'Round 2 — They come faster',
    cue: 'They are quicker now. Aim just ahead of them!',
    soldierCount: 6,
    speed: 0.13,
    zigzagAmplitude: 0.07,
    zigzagPeriod: 2.8,
    hitRadius: 0.075,
    spawnInterval: 1.6,
  ),
];

/// Level 2 — rounds 3, 4 and 5. Tighter weaving and smaller targets.
const List<ArcheryWave> kSiddimLevel2Waves = <ArcheryWave>[
  ArcheryWave(
    round: 3,
    interlude: 'The chase led them north, past the hills of Dan.',
    title: 'Round 3 — Into the valley',
    cue: 'Watch the zig-zag. Breathe, then shoot.',
    soldierCount: 7,
    speed: 0.16,
    zigzagAmplitude: 0.10,
    zigzagPeriod: 2.4,
    hitRadius: 0.068,
    spawnInterval: 1.4,
  ),
  ArcheryWave(
    round: 4,
    interlude: 'Under cover of night, they split into groups.',
    title: 'Round 4 — Tar pits ahead',
    cue: 'Keep going! Abram is counting on you.',
    soldierCount: 8,
    speed: 0.19,
    zigzagAmplitude: 0.12,
    zigzagPeriod: 2.0,
    hitRadius: 0.060,
    spawnInterval: 1.2,
  ),
  ArcheryWave(
    round: 5,
    interlude: 'The camp was close now. Steady your aim.',
    title: 'Round 5 — The night raid',
    cue: 'Almost there. Stay focused!',
    soldierCount: 9,
    speed: 0.22,
    zigzagAmplitude: 0.14,
    zigzagPeriod: 1.7,
    hitRadius: 0.054,
    spawnInterval: 1.05,
  ),
];

/// Level 3 — round 6. King Chedorlaomer, small hitbox, guarded shield.
const List<ArcheryWave> kSiddimKingWaves = <ArcheryWave>[
  ArcheryWave(
    round: 6,
    interlude: 'There he stands — King Chedorlaomer himself, behind his great shield.',
    title: 'Round 6 — King Chedorlaomer',
    cue: 'The king\'s shield takes three true arrows. Aim carefully!',
    soldierCount: 5,
    speed: 0.26,
    zigzagAmplitude: 0.16,
    zigzagPeriod: 1.4,
    hitRadius: 0.044,
    spawnInterval: 1.4,
    hitsToTurnBack: 3,
    isKingRound: true,
  ),
];
