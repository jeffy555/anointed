# Kids Zone — Implementation Reference

**Last updated:** 9 Sep 2026
**Scope:** everything shipped in `mobile/lib/features/kids_zone/` to date.

Kids Zone is a second, parallel play mode alongside the 100-level Main Journey. Where the
Main Journey is ranked, server-authoritative quiz play, Kids Zone is a set of **themed Bible
adventures made of hand-built mini-games**. It is deliberately gentler: no timers that punish,
no leaderboard, no server round-trip, and every failure state offers a retry rather than a loss.

---

## How a player reaches it

```
Sign in → level map (M-11) → PlayModeChooser → Kids Zone
```

| Route | Screen | File |
|---|---|---|
| `/kids-zone` | Adventure hub | `kids_zone_hub_screen.dart` |
| `/kids-zone/gameplay` | Mini-game host | `kids_zone_game_screen.dart` |
| `/kids-zone/complete` | Stars + celebration | `kids_zone_complete_screen.dart` |

---

## Architecture

Three pieces, deliberately decoupled so a new adventure is mostly *data*:

1. **`kids_zone_adventures.dart`** — the catalogue. An `KidsAdventure` is a themed world holding
   ordered `KidsAdventureStop`s. Each stop names a `KidsZoneGameKind`.
2. **`kids_zone_game_catalog.dart`** — maps a stop id to a `KidsZoneGameDefinition`, which carries
   that game's content (narration scenes, puzzle pieces, animal pairs, waves…).
3. **`kids_zone_game_screen.dart`** — a `switch` on `KidsZoneGameKind` that constructs the right
   game widget and hands it a single `onComplete(int stars)` callback.

Level content lives in `levels/` as plain `const` data, separate from the widgets that render it.
That split is what makes the content unit-testable without pumping widgets.

**Adding an adventure** = add data to `levels/`, register stops in `kids_zone_adventures.dart`,
add definitions to the catalog, add the enum case + `switch` arm, add ARB strings. No changes to
progress, stars, analytics or navigation.

---

## Adventure catalogue

| # | Adventure | Book | Stops | Status |
|---|---|---|---|---|
| 1 | **Creation Garden** | Genesis 1 | Intro + 3 levels | Complete |
| 2 | **Battle of Siddim** | Genesis 14 | Intro + 3 levels | Complete |
| 3 | **Noah's Ark** | Genesis 6–9 | Intro + 3 levels | Complete |
| 4 | **Baby Moses** | Exodus 1–2 | Intro + 3 levels | Complete |
| 5 | Heroes Path | — | 1 stop (Young David) | Placeholder |
| 6 | Wise Kings | — | 1 stop (Solomon's Gift) | Placeholder |

Stops unlock strictly in order — stop *n* opens once stop *n−1* is complete. Stop 0 is always open,
and a completed stop can be replayed freely.

---

## Adventure 1 — Creation Garden (Genesis 1)

| Stop | Game | Mechanic |
|---|---|---|
| Introduction | `creationIntro` | 8 narrated beats (Before Day One → Day 7); the world is painted from the day number and builds as each day is spoken |
| Level 1 — God's Questions | `listenAndAnswer` | Listening comprehension; a celebration burst per correct answer |
| Level 2 — Connect Creations | `connectCreations` | Tap a day, tap its creation; glowing lines show the links |
| Level 3 — Jumbled Challenge | `jumbledWords` | Tap words to rebuild creation sentences; rainbow finish |

### The backdrop

`widgets/creation_world_view.dart` paints the world from a single `day` number
(0–7). The scene is **cumulative** — whatever God makes on a day appears that day
and stays for the rest of the week — and the sky lerps from the previous day's
palette, so Day 1 is watched rather than cut to: formless dark brightening as
light arrives.

| Day | What the scene does |
|---|---|
| 0 | Near-black. No stars, no horizon — "darkness over the surface of the deep" |
| 1 | Sky lerps out of that darkness while a radial glow blooms. Light, but no sun |
| 2 | The horizon travels up from the foot of the frame, separating sky from sea |
| 3 | Land rises in the foreground; trees grow from the ground, flowers open |
| 4 | Sun with corona, crescent moon, 34 twinkling stars — the luminaries, three days after light |
| 5 | Fish drift through the sea band, birds cross the sky with a wing-beat |
| 6 | Animals graze the meadow; two figures stand together |
| **7** | **The sabbath — see below** |

**Day 7 is deliberately not another addition.** The climax of the week is
stillness, so instead of putting one more thing in the world, the seventh day
quiets it:

- **Motion eases to a near stop.** Drift, waves, wing-beats and twinkling all
  slow to 6% of their normal rate. Ambient motion is an *accumulated* phase
  rather than a looping controller precisely so it can be slowed smoothly
  without the world snapping back to the start of a cycle.
- **The sky dims to dusk** — the darkest palette since Day 1, closing the week
  where it began but at peace rather than in void. A test enforces that Day 7 is
  dimmer than every working day and still brighter than the void.
- **A single slow breath of warmth** pulses over the scene (4.5s period),
  replacing the pop-and-layer arrivals of the six working days, with the frame
  edges dimmed so the eye settles toward the middle.

Content: `levels/genesis_creation_level.dart`. Layout constants live in
`CreationSceneLayout` (horizon 0.56, shore 0.74) so tests can assert that sea
creatures stay in the sea and land creatures on the land.

---

## Adventure 2 — Battle of Siddim (Genesis 14)

Abraham's archery quest. Non-violent framing throughout: arrows make soldiers **turn back and
retreat**, never anything worse.

| Stop | Game | Rounds |
|---|---|---|
| Introduction | `battleIntro` | 8 narrated beats (the valley → Lot taken → the rescue → Melchizedek's blessing) |
| Level 1 — Defend the Valley | `archery` | Rounds 1–2 |
| Level 2 — The Night Rescue | `archery` | Rounds 3–5 |
| Level 3 — King's Round | `archery` | Round 6 — King Chedorlaomer |

**Archery engine** (`games/archery_game.dart`, ~1150 lines) — the largest game in the zone:

- `Ticker`-driven game loop with a `CustomPainter` field
- Drag to aim (dotted trajectory + crosshair, bow rotates, string pulls back); release to shoot.
  **The bow only arms after 30px of finger travel** — young players touch the screen constantly,
  and a stray tap costing an arrow is a punishment they cannot read. The crosshair appears only
  once armed, so "exploring" and "aiming" look different. (Before this, the guard measured
  bow-to-aim distance, so any tap up the field was hundreds of pixels away and always fired.)
- Soldiers enter at the top and weave down toward Abram's camp; crossing the camp line costs one
  of three **courage hearts**
- Six rounds escalate monotonically in speed and shrink the hitbox

**Near-miss feedback.** A shrinking target is only fair if the child can tell a
close shot from a wild one. An arrow passing within **1.5×** the hitbox radius
without landing fires a near-miss: a quick amber ring, the word *"Almost!"*, and
the soldier flinching back a step. It costs nothing — accuracy and score are
untouched — it only teaches aim. One reaction per arrow, however long it flies.

**The King's shield** reads as three unmistakable states rather than a row of
ticks, so the child always knows how close the climax is:

| Arrows left | Shield |
|---|---|
| 3 | Whole — unbroken gold ring with a soft aura |
| 2 | Cracked — silver ring split by dark fissures |
| 1 | Broken — only arcs remain, fragments adrift off the rim |

Every strike on it is deliberately unlike turning back a foot soldier: eight
sparks thrown outward, a **camera shake** across the whole valley, and **0.45s of
slow motion** (the game clock runs at 35%, while the shake and the slow-motion
timer stay on real time). Without that, the climax of the adventure would land
exactly like round one.

**Round transitions are narrated.** Rounds 2–6 open on a `_Phase.interlude`: the
valley holds still, the loop BGM ducks, and a story beat is spoken over it —
*"Under cover of night, they split into groups."* It holds for at least 3s **and**
until speech ends, so the escalation reads as the march pressing on rather than
the game arbitrarily speeding up, and the child gets a breather between rounds.
- Score = `100 + speed bonus` per soldier (`150` for the king). The speed bonus is up to **60**,
  decaying linearly over the 4.5s after a soldier appears — turn one back quickly and it is worth
  more.

**The scorecard is shown, not hidden.** Every stop ends on a card with the full breakdown —
soldiers turned back, arrows on target with a percentage, hearts remaining, points — and then the
two criteria that decide the third star, ticked or not:

| Star rule | |
|---|---|
| Let nobody reach the camp | `breaches == 0` |
| Hit with 55% of your arrows | `accuracy >= 0.55` |

Both met → ⭐⭐⭐ · one breach → ⭐⭐ · two or more → ⭐. `ArcheryScorecard` holds both the numbers
and the rule, so what a child is *shown* is computed from the very value they were *scored* on —
they cannot drift apart. A replay then has a target rather than a vague "do better".

**Screen-reader mode.** Drag-aim-release on a painted canvas is unreachable with TalkBack on, which
claims one-finger gestures for its own navigation — a custom swipe alternative would never receive
the input. So when `MediaQuery.accessibleNavigation` is true the level switches to **five focusable
lane buttons** (far left → far right); focus one, double-tap, the arrow flies down that lane. A live
region reports the nearest advancing soldier's lane so aiming is informed rather than blind. Coarser
than free aiming, but playable rather than skipped.
- Out of hearts → "try this round again" card, not a loss screen
- Rendering is driven by a `ValueNotifier` frame counter so only the field repaints per frame,
  not the whole widget tree

Content: `levels/siddim_battle_level.dart`. Backdrop: `widgets/battlefield_view.dart`.

---

## Adventure 3 — Noah's Ark (Genesis 6–9)

| Stop | Game | Mechanic |
|---|---|---|
| Introduction | `noahIntro` | 9 narrated beats; the seascape darkens, rain falls, water rises over the hills, then recedes for the dove and rainbow |
| Level 1 — Ark Builder | `arkBuilder` | Drag 24 timbers onto a glowing blueprint, across 4 stages |
| Level 2 — Two by Two | `animalMatching` | Memory match — reunite each animal with its mate |
| Level 3 — Animal Care | `animalCare` | Feed, water, clean and comfort the animals aboard |

### Level 1 — Ark Builder

Four cumulative stages; everything placed earlier stays on screen, so the Ark visibly grows.

| Stage | Pieces | Contents |
|---|---|---|
| 1 — The keel | 5 | Keel beam, bow + stern posts, 2 cross beams |
| 2 — Hull and ribs | 6 | Three hull planks, three ribs |
| 3 — Decks and cabin | 6 | Main deck, three cabin walls, upper deck, boarding ramp |
| 4 — Roof, doors and windows | 7 | Roof, great door, side hatch, two windows, skylight, mast |

`Draggable`/`DragTarget` with snap-to-blueprint. The snap zone scales with each piece's own
footprint, so a long keel accepts a long landing zone rather than a pinpoint drop. Pieces are
drawn by a `CustomPainter` with per-shape detail (grain, door handle, window bars, tapered mast).

**Magnetism.** The snap zone is generous but invisible, which read as luck. While a piece is
dragged, its blueprint outline now lerps from blueprint-blue toward warm straw and picks up a
blurred glow as the piece nears home — the child sees the pull before the drop, across a band
twice the width of the actual snap tolerance.

**Stage checkpoints.** Finishing a stage plays a 3-second painted celebration — the ark rocking
on the water, three birds landing on the new timber, and a rainbow on the final stage — before
the "next stage" button fades in at 42% of the animation. The four stages now read as four
achievements rather than one long haul.

### Level 2 — Two by Two

- Six pairs = **12 cards** in a **3 × 4** grid, sized from the space actually available so the
  whole board fits any screen with no scrolling
- Each species has exactly one male and one female card (♂/♀ badge), so a species match *is*
  a male/female pair — the "two by two" lesson is structural, not decorative
- Animals render as **emoji pictures** (🦁 🐘 🦒 🐑 🐰 🕊️ 🐢 🦋 🐻 🐴), not icon approximations
- Six of the ten catalogue animals are drawn at random per game, so replays vary
- **4 hearts**; a mismatch costs one. Out of hearts → retry, not a hard loss. Four rather than
  five because five allowed a child to brute-force twelve cards without remembering anything
- **Mercy reveal** — the first time the child drops to a single heart, every card turns face up
  for one second. It fires once per game, and turns the moment before failure into the moment
  the board finally makes sense
- **Practice mode** toggle — hearts are retired entirely (an ∞ badge replaces them) and the stop
  still completes, at one star. The way out for a child who keeps running dry
- 3D card flip via `rotateY` transform

### Level 3 — Animal Care

- **A first-play tutorial teaches the mapping before round 1.** The card pairs every need icon
  with the tool that answers it (🌿 → Feed, 💧 → Water, 🧹 → Clean, ❤️ → Comfort) and covers the
  whole play area, toolbar included — nothing is tappable until it is read. It waits for "I'm
  ready!" rather than a timer, is shown unprompted only once (persisted in `LocalStore` under
  `kids_zone_tutorial_ark_animal_care`), and afterwards lives behind a **?** button in the HUD
- `Ticker` loop: needs (feed / water / clean / comfort) appear on stalls
- **No countdown.** The ring around a waiting animal is a *happiness meter*, not a timer. A need
  is never lost and never expires: the animal simply grows less happy while it waits, and cheers
  up the instant it is cared for. Reaching the bottom docks 25 points once — and serving a sad
  animal is worth *more* than serving a content one (60 vs 40), so the recovery is the reward
- Pick a tool, tap the animal. Wrong tool nudges happiness down
- Three rounds escalate: 4 animals / 6 tasks / relaxed → 6 animals / 10 tasks / brisk
- Stars from herd happiness, sad spells and wrong-tool count:
  3★ at ≥85% happy with no sad spells and ≤2 wrong tools, 2★ at ≥60%, otherwise 1★

Content: `levels/noah_ark_level.dart` (833 lines). Backdrop: `widgets/ark_scene_view.dart`
(weather-driven sky, rain, rising water, drifting dove, covenant rainbow).

---

## Adventure 4 — Baby Moses (Exodus 1–2)

| Stop | Game | Mechanic |
|---|---|---|
| Introduction | `mosesIntro` | 8 narrated beats; Egypt bleaches, the decree drains it grey, night falls on the Nile, dawn breaks at the palace |
| Level 1 — River Rescue | `riverRescue` | Three-lane runner down the Nile, in three stages |
| Level 2 — Plagues of Egypt | `plagueSort` | Drag ten plagues onto a timeline; Egypt reacts to each one |
| Level 3 — Crossing the Sea | `seaCrossing` | Full-screen four-phase rhythm: part the sea, cross, close it behind you, celebrate |

### Introduction

Eight beats from Pharaoh's decree to the princess naming him Moses, ending on
the line that hands the child straight into Level 1: *"Now guide the basket down
the Nile, and see him home."* Written to be **spoken, not read** — short
sentences, one image per beat, because a child listening cannot re-read a clause
they lost.

**The narrator voice.** `TtsVoice.narrator` (pitch 0.72, rate 0.36) against the
everyday `TtsVoice.friendly` (1.05 / 0.45). The platform engine gives us pitch
and rate and nothing else — there is no second voice to switch to — so a bigger
voice has to be built out of those two dials. Dropping the pitch and slowing the
delivery is what turns the read-aloud voice into one telling a story rather than
asking a question. The replay button carries the same voice, so asking to hear it
again does not hand the child a brighter, faster stranger.

**Nothing waits on the speech engine.** The Next button is held briefly so a beat
is heard before it can be skipped — but the hold is timed from the *word count*
(1.2 s + 60 ms/word, clamped 2–9 s), never from `speak()` reporting that it
finished. `speak()` returns when speech *starts*, and on a device with no TTS
engine the completion may never arrive at all; waiting on it would leave the
child locked in the introduction with a dead button and no way to the level.
Narration is fired and forgotten. `moses_intro_game_test.dart` pins this: in a
test no engine ever answers, and the button still comes back.

> The other three introductions (`creationIntro`, `battleIntro`, `noahIntro`)
> still gate their Next button on `await _tts.speak(...)` and carry this same
> stranding hazard. Not changed here — flagged for a follow-up.

**Backdrop:** `widgets/moses_intro_view.dart`, driven entirely by `MosesEra` the
way the Ark intro is driven by weather, so one widget carries the arc: a bleached
Egyptian noon over brick pits, the decree draining the colour out of the sky, a
lamplit interior, night on the Nile with moonlight on the water, then dawn and
full morning gold. Each era paints a demonstrably different sky — asserted in
tests, so a beat cannot quietly stop pulling its weight.

### Level 1 — River Rescue

**This is the only lane runner in Kids Zone, and the only game with a control
scheme of its own.** Everywhere else the child looks, thinks, taps, and the game
waits. Here the river does not wait, so read the rest of this section before
changing anything in it — several decisions that look arbitrary are load-bearing.

**Why lanes and not free movement.** Three fixed lanes (`RiverLane.left/center/right`
at 0.25 / 0.5 / 0.75) rather than a continuous position. With free movement, "did
I clear that?" comes down to a few pixels, which is a judgement young children
lose every time. With lanes the answer is yes or no, and it is visible before the
child commits.

**Full screen.** No app bar, no instruction card — the river fills the whole
device, edge to edge, the way an endless runner does.
`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` hides the
status and navigation bars on entry and `dispose()` restores `edgeToEdge` so the
rest of the app is unaffected. The HUD, the exit button and the controls float
over the scene in a `SafeArea` rather than squeezing the river into a shorter box.

**Controls.** Swipe is primary, with a tap fallback that is always live —
never a mode the child has to find.

| Gesture | Action | Always-available fallback |
|---|---|---|
| Swipe left / right | One lane over | Tap the left / right third of the river |
| Swipe up | Hop a floating log | **Hop** button |
| Swipe down | Duck under a vine | **Duck** button |
| Tap the middle third | Paddle Boost | **Paddle** button |

**Swipe detection is a raw `Listener`, not `GestureDetector`.** The first
version put `onPanEnd` (velocity-gated) and `onTapUp` on one `GestureDetector` —
two separate recognisers competing in the same gesture arena. A child's swipe is
often slow and short enough that the pan recogniser never reached firing
velocity while the tap recogniser had already lost to the movement, so the
swipe visibly happened on screen and produced nothing. `_RiverGestureTracker`
tracks `onPointerDown` / `onPointerMove` / `onPointerUp` itself and fires the
move the instant the drag crosses a distance threshold (5.5% of the shorter
screen side) — no velocity, no waiting for release. That is both more forgiving
of a slow swipe and more responsive for a fast one.
`river_rescue_game_test.dart` proves it with a 10-step, 6px-per-frame crawl
that fires mid-drag, finger still down — the old detector would have missed it.

The centre lane is reachable by tapping *back* the other way, so no lane is
locked behind the middle third being the boost.

**Accessibility.** With a screen reader on, `MediaQuery.accessibleNavigation`
swaps the gesture layer out for three labelled lane buttons alongside Hop, Duck
and Paddle. This is not a convenience: TalkBack consumes one-finger swipes before
they reach the app, so gesture-only would make the level unplayable, not just
awkward. All three input paths — swipe, tap zone, button — funnel through one
`_apply(RiverMove)`, and the `onMove` testing seam proves it.

**Stages.** Hand-authored `const` timelines in `moses_exodus_level.dart`.
Tightened once already: the first pass ran 240/430/640 m (~36/53/68 s), which
put the crocodile — gated to stage 3 — about **90 seconds** into the level.
Nobody playing a runner for the first time gets that far before deciding
nothing new is coming. Current numbers:

| Stage | Length | Speed | Hazards | Blessings |
|---|---|---|---|---|
| 1 — Calm Waters | 140 m, ~18 s | 7.0 → 8.5 m/s | Reeds only, singly, wide gaps | 1 |
| 2 — River Bends | 230 m, ~24 s | 8.5 → 10.5 m/s | Reeds + logs, some paired walls | 2 |
| 3 — Near the Palace | 330 m, ~30 s | 9.8 → 12.0 m/s | All four kinds, tighter spacing | 2 |

The crocodile now shows up around **42 seconds** in — `river_rescue_game_test.dart`
has an end-to-end test ("a determined child reaches the crocodile stage well
inside a minute") that plays stages 1 and 2 to completion, taps past both
stage-cleared cards, and asserts the stage-3 intro card is on screen, so a
future re-tightening pass can't quietly drift this back out. Speed still ramps
linearly inside each stage, and each stage still deliberately *opens slower
than the last one closed* — that settle-before-it-climbs shape survived the
retune, just compressed.

**Fairness is a property of the data, not of play.** A child cannot stop to work
out an unfair pattern, so the timelines are checked by
`test/river_rescue_game_test.dart` rather than by eye:

- every wall of hazards leaves at least one **fully clear** lane;
- a lane path exists end to end **using clear lanes only**, at the stage's top
  speed — so a child who never masters hopping or ducking can still steer the
  whole river. The vertical moves are shortcuts, never gates;
- no lotus is ever placed inside a hazard;
- crocodiles never pair up, and `RiverObstacleKind.sleepyCrocodile.response` is
  `switchLane` — asserted directly, because a crocodile you *jump over* would
  break the tone the whole level is built on.

`response` is a getter on the obstacle enum rather than a field stored beside it,
so a hazard's picture and the move it demands cannot drift apart.

**The crocodile moves, and looks like one.** The first version was a static
rounded-rect blob with a bolt-on snout — motionless enough to read as a green
log rather than an animal. `_paintCrocodile` now draws a tapered torpedo-shaped
torso (a `Path`, not a rounded rect — wider through the shoulders, narrower at
both the snout and the tail), a snout with a raised brow ridge and two nostril
bumps at the tip, and a jaw line down its length. Three things animate
continuously, all on the same sine-based `phase` clock everything else in the
scene uses (deterministic, so a given frame always paints the same way):
- a slow **tail swish**, rotated from the torso joint rather than the whole
  body moving — a drifting swim, never a thrash;
- two **webbed feet** paddling gently, out of phase with each other, the way a
  floating crocodile's legs keep working even when the rest of it looks still;
- the existing **body bob** on the water.

It is still asleep — eyes shut, snore bubbles drifting — and its jaws never
open in any state, startled included. Motion is what makes it read as alive;
it was never the thing that was supposed to make it feel dangerous.

**Nothing here punishes.** A collision is a splash, a wobble and one heart —
the basket never sinks, stops or restarts, and baby Moses is never shown in
danger. Crocodiles are asleep with snore bubbles, and a bumped one wakes up
looking startled rather than angry. There is **no game over**: running out of
hearts caps the rating at one star and the run continues. The basket always
reaches the princess.

**But losing a heart still has to feel like something.** A bump that changed
nothing but a HUD number would read as the baby not having noticed — which
undersells to the child why they should care. Two responses, both driven by
state the game already tracks:
- **The baby cries.** `RiverBasketView.cry` ramps to 1 on a bump and eases back
  over 2.6 s — deliberately longer than `bump` (0.45 s), which only drives the
  splash and the camera shake. A splash reads instantly; a face needs more than
  half a second on screen to register as an expression. `_paintBabyFace` swaps
  the sleeping face (closed-eye lashes, a small content mouth) for scrunched
  brows, an open wailing mouth and two falling tears that fade out with `cry`.
- **A toast says the words the retry-not-loss rule leaves implicit.** After a
  bump: *"A splash! {n} hearts left — try again!"* (plural-aware, including a
  `=0` case — even at zero hearts the message is encouragement, not a verdict,
  since the run continues regardless). When a new stage refills a spent set of
  hearts: *"Fresh hearts — a new chance for this stretch!"* — the literal "new
  chance" said out loud rather than left for the child to notice the HUD
  refilled on its own. `_RiverToast` is `IgnorePointer`-wrapped (never the
  thing a swipe accidentally lands on) and ticks off the same `_frame` notifier
  the scene repaints from, so it can fade itself out without needing a
  `setState` just to disappear.

**Hearts and stars.** 3 hearts, refilled at the start of each stage, with 0.9 s
of grace after a bump so one wide hazard cannot drain them in a single frame run.
`riverRescueStars()` reads hearts left at the end of the *final* stage — the one
that shows what the child learned — against lotuses gathered across the whole
run: 3★ at full hearts and ≥80% of flowers, 2★ at 2+ hearts and ≥50%, 1★ for
finishing.

**Power-ups are one-way.** An angel blessing shields the basket for 5 s and
absorbs one hazard — roughly every 10–20 s now that the stages themselves run
that much shorter (the frequency scaled down with the pacing, not the
generosity: a blessing every 12 s on an 18 s stage is the same ratio as one
every 20–25 s was on the original run). Paddle Boost is once per stage and
shields for its whole 2 s burst — a speed boost that could get you hit would be
a trap, and there is no mechanic anywhere that punishes a child for *not* using
either one.

**The princess beat.** Each stage ends with the basket auto-steering to the bank
while Pharaoh's daughter waves, over a one-line narration that varies per stage.
It runs 3 s with the gesture layer switched off entirely, so a stray tap cannot
skip it — it is a story beat, not a loading screen.

**Runner "juice" in `moses_scene_view.dart`.** Three additions, all reacting to
state the game loop already tracks rather than adding new mechanics:
- **Speed streaks** — thin white lines radiate from the vanishing point once
  `speedFactor` (current speed ÷ the stage's top speed) passes 0.72, most
  visible during a Paddle Boost. Point-to-point `ui.Gradient.linear`, not a
  rect-aligned `LinearGradient` — the latter fades along the wrong axis for
  anything but a horizontal streak.
- **Camera lean** — the whole scene banks a fraction of the basket's own tilt
  around the horizon's vanishing point (not the screen centre), so a lane
  change reads as the camera turning with the basket rather than the horizon
  swinging under a fixed camera.
- **Screen shake on a bump** — a short sine-based jitter of the whole canvas,
  scaled by the same `bump` value that already drives the basket's squash.
  Deterministic rather than `Random`-based, so a given frame always paints the
  same way and stays paintable in a golden test.

Backdrop: `widgets/moses_scene_view.dart`. `RiverPerspective` maps a distance
ahead onto the screen with a non-linear curve; without that compression a hazard
appears to *decelerate* as it approaches, which is exactly backwards. The water
bands, the bank papyrus and every hazard share one distance axis, so "the reeds
look close" and "the reeds will hit me" are the same fact. `viewDepth` (how far
ahead the child can see) is 30 m rather than 26, so the fastest stage still
hands over roughly two seconds of runway despite running faster overall.

**HUD.** Pinned top-left/top-right over the scene rather than on a solid bar: a
translucent exit button, then a pill showing running **distance** (the closest
thing this level has to a score — a climbing number is what makes a runner feel
like a runner), lotus count and hearts. "Stage X of Y" was cut from this
persistent pill — it has nothing to do while the child is watching the river,
and it is still said aloud and shown at full size on the stage-intro and
stage-cleared cards.

### Level 2 — Plagues of Egypt

A sort, mechanically. The innovation is not the mechanic — it is that **the
world answers**, which is what every other Kids Zone level does and what a
plain sorting exercise would not.

**Why the living backdrop exists.** Creation layers its world day by day, the
Ark visibly grows, the river runs, the animals cheer up. A card-sorting level
with an animation on the *card* would have been the only level in the zone
where the child causes nothing to happen. `widgets/egypt_plague_view.dart` is
a palace-and-Nile scene that reacts to every correct placement, so the level
reads as *causing the ten plagues in order* rather than sorting ten pictures.
This is not a later embellishment on a finished level — it is what closes the
gap the plain design left open, and it was built first.

Ten placements, ten **distinct** effects — a shared sparkle would make two
plagues indistinguishable in the one place the child is looking, so a test
asserts every card maps to its own `PlagueEffect`:

| Placed | Egypt does |
|---|---|
| Blood | The Nile strip tints red — **and stays red** |
| Frogs | Frogs bound across the courtyard |
| Gnats | A speckled haze settles over the palace |
| Flies | Specks swarm at the palace windows |
| Livestock | The grazing animal wobbles, drifts aside and is gone |
| Boils | The guards on the steps flinch back |
| Hail | Ice and fire fall together across the sky |
| Locusts | A swarm sweeps through — and **the greenery stays gone** |
| Darkness | The whole scene drops to silhouette, then lifts |
| Firstborn | Pharaoh's crown tips off the roof and falls |

Effects run ~1.8s and clear the frame, so the scene stays legible instead of
silting up. Two persist on purpose — the red river and the stripped greenery
— because those are the two the story itself does not undo.

**Tone.** Nothing depicts suffering. The decree is an empty throne and a sealed
scroll; the livestock is *unwell then absent*, never harmed; the tenth plague
is **a crown falling, never a person**. The crown sits on the palace roof from
round 1, so the child has been looking at it for the whole level before it
finally comes off.

**Pharaoh's Resolve** (`widgets/pharaoh_resolve_meter.dart`) is the level's
one through-line. Without it the three rounds are three self-contained
puzzles with nothing carrying over; with it they are chapters. A stone heart
takes one jagged fissure per correct placement, cumulative across all three
rounds, and shatters on the tenth. It is a direct reading of the text
(*"Pharaoh's heart was hardened... until he let the people go"*), not
decoration.

It **only ever moves forward**: a wrong placement does not crack it and does
not un-crack it, so the meter is always progress and can never be experienced
as damage taken. The bar fills as resolve *breaks*, so growth is always the
child winning. The crown fall and the shatter are read from **the same
placement** — tested by playing the level end to end, because "the same
event" is only true if it survives a real run.

**Moses's Voice.** Every tray card carries its own speaker button that speaks
a first-person line in `TtsVoice.narrator` (*"I stretched out my staff, and
the Nile turned to blood"*). This closes a real accessibility gap: Plague Sort
is the most reading-dependent level in the Moses adventure, and a child who is
not yet a confident reader can now hear what a card *is* before deciding where
it goes. It fires on tap only, never automatically, so it does not talk over a
screen reader describing the card being dragged — and a test pins that tapping
the speaker does not pick the card up.

**Round-3 memory preview.** Optional. The ten names flash across the timeline
in order (0.4s each) before the tray shuffles. Defaulted from the age
collected at sign-up — on from 9, off below — and **always** toggleable either
way, so a confident younger child or a parent can turn it on. It gates
nothing and changes no star threshold. The age lookup tolerates there being no
session at all: the rest of Kids Zone is fully offline, and a level that
crashed without an account would be the only thing in the zone that did.

**Streak glow.** Three correct in a row makes the next dragged card glow gold.
Purely cosmetic. Breaking a streak costs nothing, resets no score and takes
nothing away — a wrong card simply does not extend it.

**Deliberately not built:** no timer (it would contradict the no-punitive-timer
rule and fight the memory preview, which needs unhurried attention), no
leaderboard (every other Kids Zone level is offline by design), and no
alternate valid orderings (there is one historical order, and teaching it is
the point).

**A gesture bug found while building it.** The tray was first a horizontally
scrolling list. Every card is a `Draggable`, so a sideways drag is claimed by
the card under the finger and the list never scrolls — which would have left
most of a ten-card round unreachable on a phone. It is a `Wrap` showing all
ten at once instead: the conflict is removed rather than arbitrated.

### Level 3 — Crossing the Sea

**Full screen**, like River Rescue — no app bar, no instruction card,
`immersiveSticky` on entry and `edgeToEdge` restored on the way out. The sea
fills the device, because the scale of it is the point.

The backdrop (`widgets/parted_sea_view.dart`) is the Red Sea rather than more
Nile: **deep blue water** — the Red Sea is red in name only, and an earlier
pass that took the name literally looked like blood rather than sea — against a
dark pre-dawn sky, a mountain range in silhouette, the pillar of fire over the
path, and **Moses on an outcrop at the near shore with the staff over the
water**, arm rising as the sea parts and again as it returns, so the child can
always see who is doing this. Colder and deeper than the Nile's teal, so the
two bodies of water in this adventure still read as different places.

**A paint-order bug worth remembering:** the closed sea surface was being
painted *after* the chariots, so the instant the walls met it covered the
sinking completely — the one moment the phase builds to was invisible. It is
now drawn before them, and two tests hold the beat: that the sequence spends
real frames with the chariots part-way under, and that they are never off-path
(where the painter skips them) while `sink` is running.

Four phases, tapped to a beat. Phases 1 and 2 are the crossing and **are**
scored; phases 3 and 4 are not.

| # | Phase | Scored | What happens |
|---|---|---|---|
| 1 | Raise the staff | ✅ | The walls rise with the beats that land, so the sea parting is visibly the child's doing |
| 2 | Walk through | ✅ | The people cross the dry seabed |
| 3 | **Turn back the army** | ❌ | Chariots come down the seabed, their wheels foul, they turn around and leave — *then* the sea closes |
| 4 | Safe on the far shore | ❌ | Celebration |

Phase 3 sits **before** the celebration because the singing is the reaction to
what happens in it. Its beats are `SeaBeatKind.hand` — fewer, larger and wider
apart than phase 2's rhythm circles, drawn as an outstretched hand, because
this is Moses stretching out his hand again and not another tempo exercise.

**Targets are scattered, and have to be hit.** Each beat is placed at a random
point in the frame (seeded per phase, so a retry is the same run rather than a
different one) and a tap only counts if it lands within the target's radius.
Timing alone made this a metronome a child could answer without looking at the
screen; having to find the target is what makes it a game of attention. A tap
that lands nowhere near costs nothing — a brief blush, and the beat stays live
until its window closes.

`kSeaScoredBeats` carries a comment saying in as many words that phases 3 and
4 are excluded on purpose, and a test asserts the total is **20** numerically —
so an editor who "fixes" the exclusion changes a number a test is watching
rather than silently making the game easier.

**Phase 3's clock is a state machine**, `SeaClosingSequence`, kept in
`levels/moses_exodus_level.dart` outside the widget so it can be tested
directly. Chariots approach, the taps bring the walls in, the waters meet, and
only then do the chariots go under — `sink` cannot leave zero until `seaClose`
is exactly 1. See the content-safety section above for what that ordering is
protecting and what was decided.

The child cannot fail. Tapping closes the sea sooner; tapping badly or not at
all just means `patienceSeconds` closes it anyway. Either way the phase ends.

---

## Content safety: where the line sits, and where it moved

Four levels adapt a passage whose plain text is violent. Three use the same
move; the fourth deliberately does not, and the difference is the useful part.

| Passage | The text says | The game shows |
|---|---|---|
| Genesis 14 (Siddim) | A battle | Arrows make soldiers **turn back and retreat** — never harmed |
| Exodus 12 (tenth plague) | The firstborn die | **Pharaoh's crown falls** off the palace roof — never a person |
| Exodus 14 (the crossing) | Chariots pursue | The pursuit stops well short of the far shore; **the people and the pursuit are never on the same ground** |
| Exodus 14 (the sea returns) | "there remained not so much as one of them" | **The chariots go under.** See below |

**The default is: keep the miracle, drop the outcome.** God acts, the threat is
resolved, and the resolution is shown as *protection of the people* rather than
*defeat of an enemy*. Narration is held to the same bar — no line may read as
gloating over what happens to the losing side.

**Sea Crossing's ending is a deliberate exception**, chosen as a product
decision after the alternative was built and offered. The waters return over
Pharaoh's chariots, as the account has it. What bounds it:

- **Distant silhouettes only.** No faces, no figures, nobody shown struggling.
  The chariots tip, slide under, and foam closes over where they were.
- **It is the last thing that happens, and it cannot come early.** The sinking
  is a consequence of the sea closing, so `SeaClosingSequence.sink` stays at
  zero until the walls have actually met — tested at 0, 1, 6 and 12 taps, on
  every tick. Chariots do not simply fall over; the water takes them.
- **The pursuit never reaches the people.** `maxAdvance` stops the chariots at
  60% of the path. The Israelites are all ashore before a chariot is on
  screen, and a test holds that at every step.
- **Narration stays factual, not triumphal.** *"Stretch out your hand, and the
  waters will return"*, then *"The people were safe, forever."*

If this ever grows more graphic than a children's-Bible illustration, it has
gone past what was agreed. The three rows above it are the house default, and
a new Red-Sea-adjacent or battle-adjacent adventure should start from them —
this row is the exception that was argued for, not the new baseline.

**A separate lesson worth keeping:** where safety depends on **ordering**
rather than on what is drawn, encode the ordering so it cannot regress. Both
versions of this level did that — the first gated water-closing on the army
being clear, this one gates sinking on the water having met — and in both
cases the invariant is a pure state machine with tests that drive it tick by
tick, not two animations tuned to roughly agree.

---

## Shared systems

### Game shell
`kids_zone_game_shell.dart` gives every mini-game the same chrome: title + adventure subtitle,
an instruction card with a read-aloud button, and an optional bottom action. `kidsZonePrimaryButton`
keeps CTA styling consistent.

### Visual language
`kids_zone_tokens.dart` — a playful sky world (`KidsZoneColors`, Nunito via `google_fonts`),
deliberately distinct from the Main Journey's Parchment Codex. Each adventure then layers its own
palette: `SiddimColors` (dusk over the Salt Sea), `ArkColors` (timber against rain-washed sky).

### Audio
`services/kids_zone_audio_service.dart` — three bundled loops in `assets/audio/kids_zone/`,
assigned per level:

| Track | Used by |
|---|---|
| `interesting` | Creation L1, Siddim rounds 1–2, Ark Builder, River Rescue |
| `funky` | Creation L2, Siddim rounds 3–5, Two by Two, Plagues of Egypt |
| `thrilling` | Creation L3, Siddim King's Round, Animal Care, Crossing the Sea |

BGM plays during **gameplay only** and pauses for narration/TTS (`pauseForSpeech` /
`resumeAfterSpeech`). SFX are haptics + system sounds: `playCorrect`, `playConnect`,
`playCelebrate`, `playSparkle`, `playShoot`.

### Narration
Every introduction is spoken through `TextToSpeechService` (`flutter_tts`), with a `ReadAloudButton`
on the instruction card so any prompt can be replayed. The "Next" button is disabled while speaking.

### Progress and stars
Progress is **device-local** in `LocalStore` (`kids_zone_completed_stops`, `SharedPreferences`).
Each game returns 1–3 stars through `onComplete(int stars)`; the completion screen shows the stars,
a confetti celebration, and a "next stop" hand-off. Star rules are per game — accuracy, retries,
misses, hearts remaining or final happiness, depending on the mechanic.

### Analytics
`kids_zone_entered`, `kids_zone_stop_started` (with `adventure_id`, `stop_id`, `game_kind`),
`kids_zone_stop_completed` (with `stars`).

### Localisation and accessibility
All player-facing copy is in `lib/l10n/app_en.arb` (~117 Kids Zone keys) and generated into
`lib/l10n/gen/`. Games announce state changes through `SemanticsService` (round changes, pieces
placed, pairs found, animals cared for), and interactive elements carry `Semantics` labels.

---

## File map

```
lib/features/kids_zone/
├── kids_zone_adventures.dart        catalogue of adventures + stops
├── kids_zone_game_catalog.dart      stop id → game definition + content
├── kids_zone_game_screen.dart       routes a stop to its game widget
├── kids_zone_game_shell.dart        shared chrome for every mini-game
├── kids_zone_hub_screen.dart        adventure hub, unlock + replay state
├── kids_zone_complete_screen.dart   stars + celebration
├── kids_zone_tokens.dart            colours + typography
├── play_mode_chooser.dart           Main Journey vs Kids Zone
├── levels/
│   ├── genesis_creation_level.dart  Creation Garden content
│   ├── siddim_battle_level.dart     Battle of Siddim content
│   ├── noah_ark_level.dart          Noah's Ark content
│   └── moses_exodus_level.dart      Baby Moses content
├── games/                           12 mini-game implementations
└── widgets/
    ├── creation_world_view.dart     Creation backdrop
    ├── battlefield_view.dart        Siddim valley backdrop
    ├── ark_scene_view.dart          Ark seascape backdrop
    ├── moses_scene_view.dart        Scrolling Nile backdrop
    ├── moses_intro_view.dart        Moses story backdrop
    ├── egypt_plague_view.dart       Living Egypt, reacts per plague
    ├── pharaoh_resolve_meter.dart   Cracking resolve meter
    └── parted_sea_view.dart         Parting/closing sea + chariots
```

~11,000 lines across 31 files.

---

## Testing

| File | Covers |
|---|---|
| `test/kids_zone_adventures_test.dart` | Catalogue wiring (every stop has a game, unique ids), Siddim round escalation, Ark stage growth + piece bounds, animal art, care-round escalation |
| `test/ark_builder_game_test.dart` | First-frame render, tray appearance, **the wide keel snapping** (regression) |
| `test/animal_matching_game_test.dart` | Board fits without scrolling on small **and** large handsets, six pairs dealt |
| `test/kids_zone_layout_test.dart` | **Every stop at every frame the app can produce** — 18 stops × 6 sizes, up to the 2.4 text ceiling |
| `test/kids_zone_progress_test.dart` | Stars persist and keep the best result; sign-out takes the whole record with it |

271 tests passing across the app. `flutter analyze` reports zero issues in `kids_zone/`.

### The layout suite, and why it exists

A QA sweep in Sep 2026 rendered every stop at sizes the app actually permits and found
**21 broken frames**: four stops ran off a 360×720 phone at the *default* text size, six more in
landscape, and eleven at a text scale the in-app "Large text" switch reaches on its own. The tests
that existed checked two portrait sizes at scale 1.0 — the one case that worked.

The causes were three shapes, all now handled in `kids_zone_game_shell.dart`:

- **`KidsZoneGameShell`** — the cue card and the bottom action were both intrinsic height and both
  grow with the text scale, while the game between them was an `Expanded` that gave way first. Each
  is now capped at a fraction of the height (38% / 40%) and scrolls inside its cap.
- **`KidsZoneIntroPanel`** — all four introductions had hand-built the same panel and broke
  identically. Label, narration and the replay button now scroll as one block; only the 6px
  progress bar stays pinned. One widget replaced four copies.
- **`KidsZoneBoardLayout`** — for bodies that are instructions above a board. The board is what has
  to keep working, so the chrome is capped and scrolls and the board takes the rest.

Fixed-size instruments and controls — Pharaoh's resolve meter, the river controls, the animal
stalls — scale *down* rather than out, because they are things to aim at rather than to read. The
animal emoji is marked `TextScaler.noScaling`: it is a picture, not text.

**Orientation is now locked to portrait for the zone**, set on the hub and released on the way out.
The main journey keeps its deliberate tablet and landscape layouts. The lock is a request the OS
can decline on large screens, so landscape stays in the test matrix regardless.

Two regressions are pinned by tests because they shipped and were caught on device:

- **Ark Builder tray crash** — reading the blueprint's `RenderBox.size` during build.
- **Keel unplaceable** — the drop added half the piece size to the pointer position. Harmless on
  small pieces (~30px), fatal on the 0.62-wide keel (~110px, beyond any tolerance). The test drops
  on the keel's *right-hand end* specifically, because that's where the old shift broke.

---

## Known limitations

| Item | Status | Note |
|---|---|---|
| Server sync of progress | **Deferred** | Stars and completion are device-local only; a reinstall loses them. They are now cleared on sign-out and account deletion, so a shared family device no longer hands one child another's progress |
| Heroes Path / Wise Kings | **Placeholder** | One stop each, reusing generic mini-games (`explorer`, `storyPath`). Both are labelled "Coming soon" but still render as ordinary tappable adventures — a child who taps gets a real but empty-feeling game rather than a locked door |
| Card count in Two by Two | **Reduced** | The original spec called for 20 cards; 12 is what fits a 3-wide grid at readable size |
| Animal art | **Emoji** | Renders in the platform's emoji style, so it varies slightly by OS version |
| Generic mini-games | **Unused by the built adventures** | `matchPairs`, `trailOrder`, `storyPath`, `explorer` remain for future worlds |
| Layout at 2.4x text | **Degraded, not broken** | At the app's text ceiling the cue card and the action can take 78% of the screen between them and the game is squeezed into what is left. Nothing overflows and every word stays reachable, but the games are cramped — the honest trade against clamping the type down in a children's app |
| Kids Zone typography | **Bundled** | Nunito is shipped in `assets/fonts` rather than fetched at runtime. A first launch with no connection used to lose the whole type system to Roboto, and the fetch was an unsolicited request to a third party before the consent gate |
| Sea Crossing music cue | **Unverified by ear** | `playClimax()` seeks the `thrilling` loop to 52s of its 60.07s for phase 3. The audio service had no seek at all, and the loop's position when a phase begins depends on how long the child took, so neither option in the brief worked as written — seek was added. Whether a tension riser actually sits there could not be confirmed by inspecting the file; the offset is a single named constant, ready to retune |
| River Rescue sound effects | **Haptics, not clips** | Lane switch, hop, duck, bump, lotus and blessing each have their own haptic signature, but the short custom audio clips the design calls for are not authored |

---

## Build and deploy

Kids Zone needs no backend — it is fully offline, fonts included since Sep 2026. To put a build on a phone:

```bat
D:\Anointed\scripts\deploy-phone-usb.bat <YOUR_PC_IP>
```

Then: **Kids Zone → pick an adventure → play the Introduction first** (it unlocks Level 1).
Turn media volume up for BGM and narration.
