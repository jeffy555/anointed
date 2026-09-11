import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Moses (Exodus 1–2) — Level 1, River Rescue.
///
/// River Rescue is the first **lane runner** in Kids Zone. Every other
/// adventure is turn-based: the child looks, thinks, then acts, and the game
/// waits. Here the river keeps moving, so the data model has to guarantee
/// fairness up front — a child cannot pause to work out an unfair pattern.
///
/// That is why the stage timelines below are hand-authored `const` data rather
/// than generated at runtime, matching how Siddim's waves and Ark Builder's
/// stages are tuned. The invariants that make a pattern fair (always a clear
/// lane, a lane-switch escape from every hop/duck, strict escalation) are
/// enforced by `river_rescue_game_test.dart` against this data, so a future
/// tuning pass cannot quietly introduce a trap.

/// Palette for the Nile world — teal water and papyrus against a warm sky.
class MosesColors {
  const MosesColors._();

  static const Color skyTop = Color(0xFF8ECAE6);
  static const Color skyMid = Color(0xFFBFE3EF);
  static const Color skyLow = Color(0xFFFFE8C2);
  static const Color water = Color(0xFF2E8B8B);
  static const Color waterDeep = Color(0xFF1B5E5E);
  static const Color waterLight = Color(0xFF57B8B0);
  static const Color foam = Color(0xFFE8F7F5);
  static const Color reed = Color(0xFF4E8A3C);
  static const Color reedDark = Color(0xFF2F5A24);
  static const Color reedLight = Color(0xFF7CB342);
  static const Color sand = Color(0xFFE2C48A);
  static const Color sandDark = Color(0xFFC7A46A);
  static const Color basket = Color(0xFFC8A165);
  static const Color basketDark = Color(0xFF8A6A3C);
  static const Color basketLight = Color(0xFFE3C48F);
  static const Color cloth = Color(0xFFFFF3E0);
  static const Color lotus = Color(0xFFF48FB1);
  static const Color lotusHeart = Color(0xFFFFD54F);
  static const Color blessing = Color(0xFFFFD86B);
  static const Color croc = Color(0xFF6E8B4C);
  static const Color crocDark = Color(0xFF4A6132);
  static const Color robe = Color(0xFFD8BFE8);
  static const Color robeTrim = Color(0xFFFFD86B);
  static const Color heart = Color(0xFFEF5350);
  static const Color ink = Color(0xFF12403A);

  static LinearGradient get skyGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[skyTop, skyMid, skyLow],
        stops: <double>[0.0, 0.55, 1.0],
      );
}

/// The three fixed lanes across the river.
///
/// Discrete on purpose. An earlier free-position design let the basket sit
/// between hazards, which made "did I clear that?" a matter of pixels — a
/// judgement young children lose every time. With three lanes the answer is
/// always yes or no, and the child can see which it will be before they commit.
enum RiverLane {
  left(0.25),
  center(0.5),
  right(0.75);

  const RiverLane(this.fraction);

  /// Horizontal position as a fraction of the river's width, at the basket.
  final double fraction;

  /// The lane [delta] steps to the side, or null at the edge of the river.
  RiverLane? shifted(int delta) {
    final int next = index + delta;
    if (next < 0 || next >= RiverLane.values.length) return null;
    return RiverLane.values[next];
  }
}

/// The one move that gets the basket past an obstacle.
///
/// Single-valued, and read off the obstacle kind rather than stored alongside
/// it, so a hazard's picture and the move it demands cannot drift apart.
enum RiverResponse { switchLane, hop, duck }

/// Something in the river to get past.
enum RiverObstacleKind {
  /// Tall papyrus growing across the lane — go around it.
  reedCluster,

  /// A vine arching low over the water — pass underneath.
  reedVine,

  /// A log bobbing on the surface — hop the basket over it.
  floatingLog,

  /// A dozing crocodile. Always asleep, never in the way of a hop or a duck:
  /// the only answer is to steer around, so the child is never asked to leap
  /// over an animal.
  sleepyCrocodile;

  RiverResponse get response => switch (this) {
        RiverObstacleKind.reedCluster => RiverResponse.switchLane,
        RiverObstacleKind.reedVine => RiverResponse.duck,
        RiverObstacleKind.floatingLog => RiverResponse.hop,
        RiverObstacleKind.sleepyCrocodile => RiverResponse.switchLane,
      };

  /// How much of the lane the hazard occupies vertically, for hit testing and
  /// for drawing: a vine hangs high, a log sits low, reeds and crocodiles fill
  /// the lane.
  bool get isOverhead => this == RiverObstacleKind.reedVine;
  bool get isLow => this == RiverObstacleKind.floatingLog;
}

// ------------------------------------------------------------- introduction

/// Backdrop mood for one beat of the introduction.
///
/// The story runs from a bright, oppressive Egyptian noon to a night on the
/// river and out into the dawn where the princess finds him, so the sky does
/// most of the storytelling — the same trick the Ark intro uses with weather.
enum MosesEra {
  /// Brick pits under a hard white sun — Egypt at work.
  egypt,

  /// Pharaoh's decree. The sky goes hard and colourless.
  decree,

  /// A mother hiding her baby indoors, warm lamplight against the dark.
  hiding,

  /// Weaving the basket and sealing it with pitch.
  basket,

  /// Night on the Nile, reeds and moonlight.
  river,

  /// Dawn at the palace steps, where the basket is found.
  discovery,

  /// The promise — warm gold, the whole sky lit.
  promise,
}

/// Who or what is painted into a beat of the story.
///
/// Deliberately *not* icons. The first version popped Material glyphs onto the
/// backdrop — a `shopping_basket` for the basket, a `child_care` glyph for the
/// baby — and it read exactly as what it was: a shopping basket floating on its
/// own, with no baby in it and nobody around it. These are painted figures
/// instead: people with faces and robes, and a swaddled infant drawn *inside*
/// the basket rather than beside it.
enum MosesFigureKind {
  /// A family of God's people standing together.
  family,

  /// A worker carrying a load of mud bricks.
  worker,

  /// Pharaoh's throne with the decree hanging from it. The command is shown as
  /// a scroll and an empty throne — never as anyone being harmed.
  palaceDecree,

  /// Jochebed, cradling the swaddled baby.
  motherHolding,

  /// Jochebed kneeling over the basket.
  motherWeaving,

  /// The basket afloat, with the baby's face visible above the rim.
  basketOnWater,

  /// Miriam, half-hidden, watching from the reeds.
  girlWatching,

  /// Pharaoh's daughter, reaching down toward the water.
  princessReaching,

  /// Pharaoh's daughter, holding the baby.
  princessHolding,
}

/// A painted figure and where it stands in the scene.
class MosesFigure {
  const MosesFigure({
    required this.kind,
    required this.left,
    required this.baseline,
    this.scale = 1,
  });

  final MosesFigureKind kind;

  /// Horizontal centre, as a fraction of the backdrop width.
  final double left;

  /// Where the figure's feet — or the waterline, for the basket — sit, as a
  /// fraction of the backdrop height. Figures are drawn upward from here, so
  /// they stand on the ground rather than floating at an arbitrary centre.
  final double baseline;

  /// Size relative to the scene's default figure height.
  final double scale;
}

/// One narrated beat of the Moses story.
class MosesIntroScene {
  const MosesIntroScene({
    required this.sceneLabel,
    required this.narration,
    required this.era,
    this.figures = const <MosesFigure>[],
  });

  final String sceneLabel;
  final String narration;
  final MosesEra era;
  final List<MosesFigure> figures;
}

/// Exodus 1–2, told in eight beats.
///
/// Written to be *spoken*, not read: short sentences, strong verbs, and one
/// image per beat, because the narrator voice is the thing carrying this and a
/// child listening cannot re-read a clause they lost.
const List<MosesIntroScene> kMosesIntroScenes = <MosesIntroScene>[
  MosesIntroScene(
    sceneLabel: 'A people far from home',
    narration:
        'Long ago, God\' people lived in Egypt. There were so many of them '
        'that the whole land was filled with their families. But a new king '
        'rose up over Egypt — a Pharaoh who did not remember them.',
    era: MosesEra.egypt,
    figures: <MosesFigure>[
      MosesFigure(kind: MosesFigureKind.family, left: 0.44, baseline: 0.82),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'Pharaoh\' hard command',
    narration:
        'Pharaoh was afraid of them. So he made them work under the hot sun, '
        'carrying clay and building his cities. And then he gave a terrible '
        'command: every baby boy born to God\' people must be taken away.',
    era: MosesEra.decree,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.palaceDecree, left: 0.72, baseline: 0.78),
      MosesFigure(
          kind: MosesFigureKind.worker, left: 0.22, baseline: 0.84, scale: 0.9),
      MosesFigure(
          kind: MosesFigureKind.worker, left: 0.38, baseline: 0.88, scale: 1.0),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'A baby is born',
    narration:
        'In one small house, a baby boy was born. His mother looked at him '
        'and saw that he was beautiful. She would not let him be taken. So she '
        'hid him — for one month, and then two, and then three.',
    era: MosesEra.hiding,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.motherHolding,
          left: 0.48,
          baseline: 0.88,
          scale: 1.3),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'The basket',
    narration:
        'But a baby grows, and a baby cries, and soon he could not be hidden '
        'any longer. So his mother wove a basket out of river reeds. She '
        'painted it with tar and pitch, so not one drop of water could get in.',
    era: MosesEra.basket,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.motherWeaving,
          left: 0.46,
          baseline: 0.88,
          scale: 1.25),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'Down to the water',
    narration:
        'She carried the basket down to the great river Nile, and she set it '
        'gently among the tall reeds at the water\' edge. Then she let go. '
        'Of all the brave things a mother has ever done, that was one.',
    era: MosesEra.river,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.motherWeaving,
          left: 0.22,
          baseline: 0.76,
          scale: 1.0),
      MosesFigure(
          kind: MosesFigureKind.basketOnWater,
          left: 0.60,
          baseline: 0.88,
          scale: 1.2),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'Miriam watches',
    narration:
        'His big sister Miriam did not go home. She stood a little way off, '
        'behind the reeds, watching the basket — because somebody had to know '
        'what happened to him.',
    era: MosesEra.river,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.girlWatching,
          left: 0.80,
          baseline: 0.80,
          scale: 1.0),
      MosesFigure(
          kind: MosesFigureKind.basketOnWater,
          left: 0.34,
          baseline: 0.90,
          scale: 1.15),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'The princess at the river',
    narration:
        'Now Pharaoh\' own daughter came down to the river to wash. She saw '
        'the basket among the reeds and sent her servant to fetch it. She '
        'opened it — and there was the baby, crying. And her heart went out '
        'to him.',
    era: MosesEra.discovery,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.princessReaching,
          left: 0.68,
          baseline: 0.82,
          scale: 1.3),
      MosesFigure(
          kind: MosesFigureKind.basketOnWater,
          left: 0.34,
          baseline: 0.90,
          scale: 1.15),
    ],
  ),
  MosesIntroScene(
    sceneLabel: 'Drawn out of the water',
    narration:
        'She named him Moses, which means "drawn out" — because she drew him '
        'out of the water. Pharaoh had said the river would take him. God '
        'used that very river to carry him safely to a palace. Now guide the '
        'basket down the Nile, and see him home.',
    era: MosesEra.promise,
    figures: <MosesFigure>[
      MosesFigure(
          kind: MosesFigureKind.princessHolding,
          left: 0.48,
          baseline: 0.86,
          scale: 1.4),
    ],
  ),
];

// -------------------------------------------------------- Level 2: plagues

/// What the backdrop does when a plague is placed correctly.
///
/// A typed effect rather than the string id the brief sketched, for the same
/// reason `RiverObstacleKind.response` is a getter: a card's picture and the
/// thing it makes happen to Egypt cannot then drift apart in a later edit.
/// Each value is a *distinct* effect — the whole point of the living backdrop
/// is that the ten plagues are ten different events, not one sparkle reused.
enum PlagueEffect {
  /// The Nile strip along the bottom tints red.
  bloodRiver,

  /// Frogs hop across the courtyard.
  frogs,

  /// A speckled haze drifts over the palace.
  gnats,

  /// Dark specks swarm at the palace windows.
  flies,

  /// A grazing animal wobbles and drifts aside. Never shown harmed.
  livestock,

  /// The guards on the steps pause and flinch.
  boils,

  /// Ice and fire fall across the top of the scene.
  hail,

  /// A swarm sweeps through and the greenery goes with it.
  locusts,

  /// The whole scene drops to silhouette, then partly lifts.
  darkness,

  /// Pharaoh's crown tips off the palace roof — the payoff beat, and the
  /// only way the tenth plague is ever depicted. A crown falls; no person
  /// is shown.
  crownFall,
}

/// One plague card.
class PlagueCard {
  const PlagueCard({
    required this.order,
    required this.name,
    required this.emoji,
    required this.effect,
  });

  /// 1-10, the historical order. There is exactly one correct sequence — the
  /// level teaches that sequence, so no alternative ordering is accepted.
  final int order;
  final String name;
  final String emoji;

  /// What Egypt does when this card lands in the right slot.
  final PlagueEffect effect;
}

/// The ten, in order.
const List<PlagueCard> kMosesPlagues = <PlagueCard>[
  PlagueCard(
      order: 1, name: 'Blood', emoji: '🩸', effect: PlagueEffect.bloodRiver),
  PlagueCard(order: 2, name: 'Frogs', emoji: '🐸', effect: PlagueEffect.frogs),
  PlagueCard(order: 3, name: 'Gnats', emoji: '🦟', effect: PlagueEffect.gnats),
  PlagueCard(order: 4, name: 'Flies', emoji: '🪰', effect: PlagueEffect.flies),
  PlagueCard(
      order: 5, name: 'Livestock', emoji: '🐄', effect: PlagueEffect.livestock),
  PlagueCard(order: 6, name: 'Boils', emoji: '🫙', effect: PlagueEffect.boils),
  PlagueCard(order: 7, name: 'Hail', emoji: '🧊', effect: PlagueEffect.hail),
  PlagueCard(
      order: 8, name: 'Locusts', emoji: '🦗', effect: PlagueEffect.locusts),
  PlagueCard(
      order: 9, name: 'Darkness', emoji: '🌑', effect: PlagueEffect.darkness),
  PlagueCard(
      order: 10,
      name: 'The Firstborn',
      emoji: '👑',
      effect: PlagueEffect.crownFall),
];

/// One round of the sort: which plagues are in play, and the slots to fill.
class PlagueRound {
  const PlagueRound({
    required this.round,
    required this.title,
    required this.cue,
    required this.orders,
  });

  final int round;
  final String title;
  final String cue;

  /// The `PlagueCard.order` values dealt this round, in story order.
  final List<int> orders;

  List<PlagueCard> get cards => kMosesPlagues
      .where((PlagueCard c) => orders.contains(c.order))
      .toList(growable: false);
}

/// Three rounds: the first five, the second five, then all ten.
const List<PlagueRound> kMosesPlagueRounds = <PlagueRound>[
  PlagueRound(
    round: 1,
    title: 'The first five',
    cue: 'Drag each plague onto the right step. Tap the speaker to hear it.',
    orders: <int>[1, 2, 3, 4, 5],
  ),
  PlagueRound(
    round: 2,
    title: 'The next five',
    cue: 'Pharaoh still will not listen. Put the next five in order.',
    orders: <int>[6, 7, 8, 9, 10],
  ),
  PlagueRound(
    round: 3,
    title: 'All ten, in order',
    cue: 'Now the whole story, from the river to the crown.',
    orders: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ),
];

/// Correct placements needed to break Pharaoh's resolve completely.
///
/// Ten, cumulative across all three rounds — the meter is the one thing that
/// spans the whole level, so a round is a chapter of it rather than a
/// self-contained puzzle. Wrong attempts never crack it, so the meter reads
/// as progress and never as damage.
const int kPharaohResolveCracks = 10;

/// Consecutive correct placements before the drag glows gold.
const int kPlagueStreakGlow = 3;

/// Youngest age the round-3 memory preview is on by default for.
///
/// Below this it stays off — a memory layer is a difficulty preference, not a
/// rite of passage — and the toggle is always offered either way, so a
/// confident younger child (or a parent) can turn it on.
const int kPlaguePreviewDefaultAge = 9;

/// Stars for a Plague Sort attempt.
///
/// Reads only correct placements against wrong attempts. There is no timer and
/// no streak requirement: a child who gets there slowly, or who breaks every
/// streak on the way, can still earn three stars.
int plagueSortStars({required int correct, required int wrongAttempts}) {
  if (correct < kPharaohResolveCracks) return 1;
  if (wrongAttempts <= 2) return 3;
  if (wrongAttempts <= 6) return 2;
  return 1;
}

// --------------------------------------------------- Level 3: sea crossing

/// A tap target in the crossing.
enum SeaBeatKind {
  /// Phases 1-2: an ordinary step of the rhythm.
  step,

  /// Phase 3: Moses stretching out his hand again. Fewer, larger, slower,
  /// and drawn as a hand rather than a circle, so the child reads it as the
  /// same deliberate act rather than more of the same tempo exercise.
  hand,
}

/// One tap target, at a time within its phase.
class SeaBeat {
  const SeaBeat({required this.time, this.kind = SeaBeatKind.step});

  /// Seconds from the start of the phase.
  final double time;
  final SeaBeatKind kind;
}

/// How the sea and the shore look during a phase.
enum SeaStage { closed, parting, parted, closing, calm }

/// One phase of the crossing.
class SeaPhase {
  const SeaPhase({
    required this.id,
    required this.title,
    required this.cue,
    required this.durationSec,
    required this.stage,
    required this.beats,
    this.isScored = true,
    this.narration = '',
  });

  final String id;
  final String title;
  final String cue;
  final double durationSec;
  final SeaStage stage;
  final List<SeaBeat> beats;

  /// Whether this phase's beats count toward the stars.
  final bool isScored;

  /// Spoken when the phase opens.
  final String narration;
}

/// The chariots that come down the seabed in phase 3.
///
/// Their own model rather than more `SeaBeat`s: a chariot needs a position
/// and an exit to track, which the generic beat-hit model has nowhere to put.
class ChariotWave {
  const ChariotWave({required this.count, required this.laneOffsets});

  /// How many silhouettes render.
  final int count;

  /// Horizontal spread across the path, as fractions of its half-width.
  final List<double> laneOffsets;
}

const ChariotWave kMosesChariots = ChariotWave(
  count: 3,
  laneOffsets: <double>[-0.52, 0.02, 0.55],
);

/// Exodus 14, in four phases.
///
/// Phase 3 sits between the crossing and the celebration because the
/// celebration is the reaction *to* it — singing on the far shore only means
/// anything once the danger has actually turned around.
const List<SeaPhase> kMosesSeaPhases = <SeaPhase>[
  SeaPhase(
    id: 'raise_the_staff',
    title: 'Raise the staff',
    cue: 'Tap each glow to hold the staff steady over the water.',
    narration:
        'Moses raised his staff over the sea, and God sent a strong wind '
        'that drove the water back all night.',
    durationSec: 14,
    stage: SeaStage.parting,
    beats: <SeaBeat>[
      SeaBeat(time: 1.0),
      SeaBeat(time: 2.6),
      SeaBeat(time: 4.2),
      SeaBeat(time: 5.8),
      SeaBeat(time: 7.4),
      SeaBeat(time: 9.0),
      SeaBeat(time: 10.6),
      SeaBeat(time: 12.2),
    ],
  ),
  SeaPhase(
    id: 'walk_through',
    title: 'Walk through',
    cue: 'Keep the beat and walk everyone across the dry ground.',
    narration:
        'The water stood up like walls on their right and on their left, and '
        'the people walked through on dry ground.',
    durationSec: 16,
    stage: SeaStage.parted,
    beats: <SeaBeat>[
      SeaBeat(time: 0.8),
      SeaBeat(time: 2.0),
      SeaBeat(time: 3.2),
      SeaBeat(time: 4.4),
      SeaBeat(time: 5.6),
      SeaBeat(time: 6.8),
      SeaBeat(time: 8.0),
      SeaBeat(time: 9.2),
      SeaBeat(time: 10.4),
      SeaBeat(time: 11.6),
      SeaBeat(time: 12.8),
      SeaBeat(time: 14.0),
    ],
  ),
  SeaPhase(
    id: 'turn_back_army',
    title: 'Turn back the army',
    cue: 'Stretch out your hand again. The sea will do the rest.',
    narration: "But Pharaoh's chariots raced after them into the sea!",
    durationSec: 18,
    stage: SeaStage.closing,
    // Unscored: a beat the child *enacts*, not a skill they are measured on.
    isScored: false,
    beats: <SeaBeat>[
      SeaBeat(time: 0.0, kind: SeaBeatKind.hand),
      SeaBeat(time: 2.5, kind: SeaBeatKind.hand),
      SeaBeat(time: 5.0, kind: SeaBeatKind.hand),
      SeaBeat(time: 7.5, kind: SeaBeatKind.hand),
      SeaBeat(time: 10.0, kind: SeaBeatKind.hand),
      SeaBeat(time: 12.5, kind: SeaBeatKind.hand),
      SeaBeat(time: 15.0, kind: SeaBeatKind.hand),
    ],
  ),
  SeaPhase(
    id: 'celebration',
    title: 'Safe on the far shore',
    cue: 'Everyone is across. Celebrate!',
    narration: 'The people were safe, forever.',
    durationSec: 10,
    stage: SeaStage.calm,
    isScored: false,
    beats: <SeaBeat>[
      SeaBeat(time: 1.0),
      SeaBeat(time: 2.4),
      SeaBeat(time: 3.8),
      SeaBeat(time: 5.2),
      SeaBeat(time: 6.6),
    ],
  ),
];

/// Every beat the stars are actually read from.
///
/// **Phases 3 and 4 are excluded on purpose.** `turn_back_army` is a
/// narrative beat the child enacts and `celebration` is a reward — neither is
/// a skill test, and folding either into the score would turn "watch the
/// story happen" into "perform the story correctly". If you are here because
/// the total looks wrong, this is the intended total: do not add them.
int get kSeaScoredBeats => kMosesSeaPhases
    .where((SeaPhase p) => p.isScored)
    .fold(0, (int sum, SeaPhase p) => sum + p.beats.length);

/// Stars for a Sea Crossing attempt, from the scored phases only.
int seaCrossingStars({required int hits}) {
  final int total = kSeaScoredBeats;
  if (total == 0) return 3;
  final double share = hits / total;
  if (share >= 0.85) return 3;
  if (share >= 0.55) return 2;
  return 1;
}

/// Where the sea is in its return.
enum SeaClosingStage {
  /// Chariots coming down the seabed from the near shore.
  approaching,

  /// Moses has his hand out and the walls are falling inward. Driven by taps,
  /// so the closing is visibly the child's doing rather than a cutscene they
  /// waited through.
  closing,

  /// The waters have met. Chariots go under as a distant silhouette.
  swallowed,

  /// Still water, edge to edge.
  still,
}

/// Phase 3's clock, kept out of the widget so it can be tested directly.
///
/// The child cannot fail here: taps close the sea faster, and
/// [patienceSeconds] closes it anyway for a child who taps little or not at
/// all. Either way the phase ends and the story arrives where it is going.
class SeaClosingSequence {
  SeaClosingSequence();

  /// Taps that close the sea on their own.
  static const int hitsToClose = 6;

  /// The sea returns on its own after this long, however the child taps.
  static const double patienceSeconds = 16;

  /// How long the chariots take to go under, and how long the water then
  /// lies still before the celebration.
  static const double swallowSeconds = 2.2;
  static const double stillSeconds = 1.4;

  /// How far down the seabed the chariots get, as a fraction of the path.
  /// Well short of the far shore: the people are already across, and the
  /// pursuit never reaches the ground they are standing on.
  static const double maxAdvance = 0.6;

  SeaClosingStage _stage = SeaClosingStage.approaching;
  double _stageT = 0;
  double _elapsed = 0;
  int _hits = 0;
  double _wobble = 0;
  double _advance = 0;
  double _close = 0;

  SeaClosingStage get stage => _stage;
  int get hits => _hits;
  double get elapsed => _elapsed;

  /// A decaying jolt after each hit, for the wheel-wobble animation.
  double get wheelWobble => _wobble;

  /// Chariot position along the seabed: 0 at the near shore, 1 at the far one.
  double get chariotAdvance => _advance;

  /// How far the walls have closed. 0 = fully parted, 1 = met in the middle.
  double get seaClose => _close.clamp(0.0, 1.0);

  /// How far the chariots have gone under, 0..1. Only ever above zero once
  /// the walls have actually met.
  double get sink {
    if (_stage == SeaClosingStage.swallowed) {
      return (_stageT / swallowSeconds).clamp(0.0, 1.0);
    }
    return _stage == SeaClosingStage.still ? 1 : 0;
  }

  bool get finished =>
      _stage == SeaClosingStage.still && _stageT >= stillSeconds;

  void registerHit() {
    if (_stage != SeaClosingStage.approaching &&
        _stage != SeaClosingStage.closing) {
      return;
    }
    _hits++;
    _wobble = 1;
    _stage = SeaClosingStage.closing;
  }

  void _enter(SeaClosingStage next) {
    _stage = next;
    _stageT = 0;
  }

  void tick(double dt) {
    _elapsed += dt;
    _stageT += dt;
    if (_wobble > 0) _wobble = math.max(0, _wobble - dt / 0.45);

    switch (_stage) {
      case SeaClosingStage.approaching:
        _advance = math.min(maxAdvance, _advance + 0.13 * dt);
        if (_elapsed >= patienceSeconds) _enter(SeaClosingStage.closing);
      case SeaClosingStage.closing:
        // Chariots slow as their wheels foul, and the walls come in with the
        // taps — plus a floor, so a child who stops tapping still gets there.
        _advance = math.min(maxAdvance, _advance + 0.04 * dt);
        final double byHits = _hits / hitsToClose;
        final double byPatience =
            ((_elapsed - patienceSeconds) / 4).clamp(0.0, 1.0);
        final double target = math.max(byHits, byPatience).clamp(0.0, 1.0);
        // Eased toward the target so each tap is a surge rather than a step.
        _close += (target - _close) * math.min(1, dt * 3.2);
        if (_close >= 0.985) {
          _close = 1;
          _enter(SeaClosingStage.swallowed);
        }
      case SeaClosingStage.swallowed:
        _close = 1;
        if (_stageT >= swallowSeconds) _enter(SeaClosingStage.still);
      case SeaClosingStage.still:
        _close = 1;
    }
  }
}

/// One hazard on a stage's timeline.
class RiverSpawn {
  const RiverSpawn({
    required this.distance,
    required this.lane,
    required this.kind,
  });

  /// Metres downstream from the start of the stage.
  final double distance;
  final RiverLane lane;
  final RiverObstacleKind kind;
}

/// A lotus flower to collect. Cosmetic to miss — lotuses feed the star rating,
/// never the ability to finish.
class RiverLotus {
  const RiverLotus({required this.distance, required this.lane});

  final double distance;
  final RiverLane lane;
}

/// A rare descending blessing that shields the basket for a few seconds.
///
/// Deliberately not a score item. It exists so a child who is struggling gets a
/// breather at roughly the moment they need one, which is why the spacing is
/// hand-placed rather than random.
class AngelBlessing {
  const AngelBlessing({required this.distance, required this.lane});

  final double distance;
  final RiverLane lane;
}

/// One stage of the run — a stretch of river ending at the bank.
class RiverStage {
  const RiverStage({
    required this.id,
    required this.title,
    required this.cue,
    required this.length,
    required this.startSpeed,
    required this.endSpeed,
    required this.arrivalNarration,
    required this.obstacles,
    required this.lotuses,
    required this.blessings,
  });

  final String id;
  final String title;

  /// Read aloud when the stage opens.
  final String cue;

  /// Metres of river before the basket reaches the bank.
  final double length;

  /// Metres per second at the start and the end of the stage. Speed ramps
  /// linearly between them so the change is felt gradually rather than as a
  /// step — a sudden jump reads as the game breaking, not as getting harder.
  final double startSpeed;
  final double endSpeed;

  /// Spoken over the princess arrival beat.
  final String arrivalNarration;

  final List<RiverSpawn> obstacles;
  final List<RiverLotus> lotuses;
  final List<AngelBlessing> blessings;

  double speedAt(double travelled) {
    final double t = (travelled / length).clamp(0.0, 1.0);
    return startSpeed + (endSpeed - startSpeed) * t;
  }

  /// Seconds of play, integrating the linear speed ramp.
  double get approximateSeconds => length / ((startSpeed + endSpeed) / 2);
}

/// Stars for a River Rescue run.
///
/// Hearts refill at the start of each stage, so this reads the hearts left at
/// the end of the *final* stage — the stage that shows what the child actually
/// learned — against lotuses gathered across the whole run. Finishing is always
/// worth a star: there is no game over in River Rescue, so running out of
/// hearts caps the rating rather than ending the level.
int riverRescueStars({
  required int heartsRemaining,
  required int lotusCollected,
  required int lotusAvailable,
}) {
  final double share =
      lotusAvailable <= 0 ? 1 : lotusCollected / lotusAvailable;
  if (heartsRemaining >= kRiverStartingHearts && share >= 0.8) return 3;
  if (heartsRemaining >= 2 && share >= 0.5) return 2;
  return 1;
}

/// Hearts at the start of every stage. A bump costs one; nothing costs more.
const int kRiverStartingHearts = 3;

/// Seconds of shield an angel blessing grants.
const double kRiverBlessingSeconds = 5;

/// Seconds the paddle boost runs for, and how much faster it goes. The boost
/// also shields, so choosing to use it can never cost the child a heart.
const double kRiverBoostSeconds = 2.0;
const double kRiverBoostFactor = 1.6;

// --------------------------------------------------------- stage timelines
//
// Hand-tunable const data. Distances are metres downstream. Every cluster of
// hazards leaves at least one fully clear lane, and consecutive clusters share
// one, so a child who never learns to hop or duck can still steer the whole
// river — the moves are shortcuts, never gates.
//
// Stages run short and dense on purpose — a child should meet real variety
// inside the first minute, not float past a wall of reeds for a minute and
// a half before anything new shows up. The crocodile (stage 3 only) now
// appears around 42 seconds in rather than 89.

const List<RiverSpawn> _kStage1Obstacles = <RiverSpawn>[
  RiverSpawn(
      distance: 16.0,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 30.0,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 44.2,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 57.6,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 72.9,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 87.6,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 103.3,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 115.7,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
];

const List<RiverLotus> _kStage1Lotuses = <RiverLotus>[
  RiverLotus(distance: 6.4, lane: RiverLane.center),
  RiverLotus(distance: 12.8, lane: RiverLane.center),
  RiverLotus(distance: 22.4, lane: RiverLane.center),
  RiverLotus(distance: 31.1, lane: RiverLane.left),
  RiverLotus(distance: 39.4, lane: RiverLane.center),
  RiverLotus(distance: 48.4, lane: RiverLane.right),
  RiverLotus(distance: 55.3, lane: RiverLane.left),
  RiverLotus(distance: 63.4, lane: RiverLane.right),
  RiverLotus(distance: 72.2, lane: RiverLane.center),
  RiverLotus(distance: 80.3, lane: RiverLane.left),
  RiverLotus(distance: 87.2, lane: RiverLane.left),
  RiverLotus(distance: 95.6, lane: RiverLane.right),
  RiverLotus(distance: 104.3, lane: RiverLane.left),
  RiverLotus(distance: 113.9, lane: RiverLane.center),
  RiverLotus(distance: 123.6, lane: RiverLane.right),
];

const List<AngelBlessing> _kStage1Blessings = <AngelBlessing>[
  AngelBlessing(distance: 70.0, lane: RiverLane.center),
];

const List<RiverSpawn> _kStage2Obstacles = <RiverSpawn>[
  RiverSpawn(
      distance: 14.0,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 14.0,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 23.7,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 34.0,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 43.4,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 56.2,
      lane: RiverLane.right,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 66.3,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 78.7,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 88.8,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 100.9,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 113.3,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 123.6,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 135.2,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 146.0,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 155.4,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 155.4,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 168.1,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 179.5,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 189.6,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 202.3,
      lane: RiverLane.right,
      kind: RiverObstacleKind.floatingLog),
];

const List<RiverLotus> _kStage2Lotuses = <RiverLotus>[
  RiverLotus(distance: 5.6, lane: RiverLane.right),
  RiverLotus(distance: 11.9, lane: RiverLane.center),
  RiverLotus(distance: 18.4, lane: RiverLane.center),
  RiverLotus(distance: 26.6, lane: RiverLane.left),
  RiverLotus(distance: 35.1, lane: RiverLane.right),
  RiverLotus(distance: 42.9, lane: RiverLane.left),
  RiverLotus(distance: 51.4, lane: RiverLane.left),
  RiverLotus(distance: 58.9, lane: RiverLane.left),
  RiverLotus(distance: 66.7, lane: RiverLane.center),
  RiverLotus(distance: 74.0, lane: RiverLane.right),
  RiverLotus(distance: 83.5, lane: RiverLane.right),
  RiverLotus(distance: 91.1, lane: RiverLane.left),
  RiverLotus(distance: 98.9, lane: RiverLane.left),
  RiverLotus(distance: 107.5, lane: RiverLane.center),
  RiverLotus(distance: 114.2, lane: RiverLane.left),
  RiverLotus(distance: 123.4, lane: RiverLane.left),
  RiverLotus(distance: 131.1, lane: RiverLane.left),
  RiverLotus(distance: 140.7, lane: RiverLane.center),
  RiverLotus(distance: 148.9, lane: RiverLane.center),
  RiverLotus(distance: 157.4, lane: RiverLane.center),
  RiverLotus(distance: 166.4, lane: RiverLane.center),
  RiverLotus(distance: 172.7, lane: RiverLane.right),
  RiverLotus(distance: 179.5, lane: RiverLane.right),
  RiverLotus(distance: 187.9, lane: RiverLane.right),
  RiverLotus(distance: 196.3, lane: RiverLane.right),
  RiverLotus(distance: 203.7, lane: RiverLane.left),
  RiverLotus(distance: 211.7, lane: RiverLane.left),
  RiverLotus(distance: 218.9, lane: RiverLane.right),
];

const List<AngelBlessing> _kStage2Blessings = <AngelBlessing>[
  AngelBlessing(distance: 76.7, lane: RiverLane.right),
  AngelBlessing(distance: 153.3, lane: RiverLane.center),
];

const List<RiverSpawn> _kStage3Obstacles = <RiverSpawn>[
  RiverSpawn(
      distance: 12.0, lane: RiverLane.left, kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 22.5,
      lane: RiverLane.right,
      kind: RiverObstacleKind.sleepyCrocodile),
  RiverSpawn(
      distance: 33.0, lane: RiverLane.right, kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 44.9,
      lane: RiverLane.right,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 55.9,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 66.9,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 77.8,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 88.9,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 98.8,
      lane: RiverLane.center,
      kind: RiverObstacleKind.sleepyCrocodile),
  RiverSpawn(
      distance: 108.9,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 119.6,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 129.2,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 141.3,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 151.4, lane: RiverLane.right, kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 163.0,
      lane: RiverLane.left,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 173.1,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 185.1,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 196.6,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 206.1,
      lane: RiverLane.left,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 206.1,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 217.1, lane: RiverLane.left, kind: RiverObstacleKind.reedVine),
  RiverSpawn(
      distance: 227.6,
      lane: RiverLane.center,
      kind: RiverObstacleKind.floatingLog),
  RiverSpawn(
      distance: 237.3,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 248.5,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 259.8,
      lane: RiverLane.left,
      kind: RiverObstacleKind.sleepyCrocodile),
  RiverSpawn(
      distance: 269.8,
      lane: RiverLane.left,
      kind: RiverObstacleKind.sleepyCrocodile),
  RiverSpawn(
      distance: 281.8,
      lane: RiverLane.right,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 293.5,
      lane: RiverLane.center,
      kind: RiverObstacleKind.reedCluster),
  RiverSpawn(
      distance: 304.0,
      lane: RiverLane.right,
      kind: RiverObstacleKind.floatingLog),
];

const List<RiverLotus> _kStage3Lotuses = <RiverLotus>[
  RiverLotus(distance: 4.8, lane: RiverLane.right),
  RiverLotus(distance: 11.0, lane: RiverLane.right),
  RiverLotus(distance: 20.0, lane: RiverLane.left),
  RiverLotus(distance: 29.4, lane: RiverLane.center),
  RiverLotus(distance: 37.7, lane: RiverLane.left),
  RiverLotus(distance: 44.3, lane: RiverLane.center),
  RiverLotus(distance: 54.1, lane: RiverLane.center),
  RiverLotus(distance: 61.5, lane: RiverLane.center),
  RiverLotus(distance: 70.9, lane: RiverLane.left),
  RiverLotus(distance: 78.8, lane: RiverLane.center),
  RiverLotus(distance: 87.1, lane: RiverLane.right),
  RiverLotus(distance: 95.5, lane: RiverLane.right),
  RiverLotus(distance: 104.3, lane: RiverLane.right),
  RiverLotus(distance: 112.4, lane: RiverLane.left),
  RiverLotus(distance: 119.6, lane: RiverLane.right),
  RiverLotus(distance: 127.9, lane: RiverLane.right),
  RiverLotus(distance: 137.7, lane: RiverLane.right),
  RiverLotus(distance: 145.1, lane: RiverLane.center),
  RiverLotus(distance: 151.8, lane: RiverLane.center),
  RiverLotus(distance: 159.4, lane: RiverLane.right),
  RiverLotus(distance: 168.6, lane: RiverLane.left),
  RiverLotus(distance: 176.6, lane: RiverLane.left),
  RiverLotus(distance: 183.4, lane: RiverLane.left),
  RiverLotus(distance: 191.5, lane: RiverLane.right),
  RiverLotus(distance: 200.7, lane: RiverLane.left),
  RiverLotus(distance: 207.5, lane: RiverLane.right),
  RiverLotus(distance: 216.6, lane: RiverLane.center),
  RiverLotus(distance: 223.5, lane: RiverLane.left),
  RiverLotus(distance: 230.6, lane: RiverLane.right),
  RiverLotus(distance: 238.1, lane: RiverLane.center),
  RiverLotus(distance: 244.3, lane: RiverLane.left),
  RiverLotus(distance: 252.4, lane: RiverLane.left),
  RiverLotus(distance: 258.6, lane: RiverLane.center),
  RiverLotus(distance: 268.0, lane: RiverLane.right),
  RiverLotus(distance: 277.5, lane: RiverLane.center),
  RiverLotus(distance: 287.0, lane: RiverLane.right),
  RiverLotus(distance: 294.8, lane: RiverLane.right),
  RiverLotus(distance: 302.0, lane: RiverLane.center),
  RiverLotus(distance: 308.3, lane: RiverLane.left),
  RiverLotus(distance: 317.5, lane: RiverLane.right),
];

const List<AngelBlessing> _kStage3Blessings = <AngelBlessing>[
  AngelBlessing(distance: 110.0, lane: RiverLane.left),
  AngelBlessing(distance: 220.0, lane: RiverLane.center),
];

const List<RiverStage> kMosesRiverStages = <RiverStage>[
  RiverStage(
    id: 'calm_waters',
    title: 'Calm Waters',
    cue: 'The river is gentle here. Swipe left or right to steer the basket.',
    length: 140,
    startSpeed: 7.0,
    endSpeed: 8.5,
    arrivalNarration: 'Someone is watching from the riverbank...',
    obstacles: _kStage1Obstacles,
    lotuses: _kStage1Lotuses,
    blessings: _kStage1Blessings,
  ),
  RiverStage(
    id: 'river_bends',
    title: 'River Bends',
    cue: 'The current quickens. Swipe up to hop over the floating logs.',
    length: 230,
    startSpeed: 8.5,
    endSpeed: 10.5,
    arrivalNarration: 'The basket drifts closer to the palace steps...',
    obstacles: _kStage2Obstacles,
    lotuses: _kStage2Lotuses,
    blessings: _kStage2Blessings,
  ),
  RiverStage(
    id: 'near_the_palace',
    title: 'Near the Palace',
    cue: 'Almost there! Swipe down to duck under the vines, and steer around '
        'the sleeping crocodiles.',
    length: 330,
    startSpeed: 9.8,
    endSpeed: 12.0,
    arrivalNarration: 'At last, the basket reaches the princess.',
    obstacles: _kStage3Obstacles,
    lotuses: _kStage3Lotuses,
    blessings: _kStage3Blessings,
  ),
];

/// Total lotuses on the river, across all three stages.
int get kMosesRiverLotusTotal => kMosesRiverStages.fold(
    0, (int sum, RiverStage s) => sum + s.lotuses.length);
