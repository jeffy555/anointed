import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../../../widgets/state_views.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_tokens.dart';
import '../widgets/moses_scene_view.dart';

/// Moses Level 1 — River Rescue, a three-lane runner down the Nile.
///
/// This is the only Kids Zone game the child cannot pause by thinking, so the
/// design leans hard the other way everywhere else: a bump costs a heart and
/// nothing more, running out of hearts does not end the stage, and the basket
/// always reaches the princess. The escalation lives in the river, never in the
/// consequences.
class RiverRescueGame extends StatefulWidget {
  const RiverRescueGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
    this.onMove,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  /// Testing seam. Every move the game accepts is reported here, whether it
  /// came from a swipe, a tap zone or an accessibility button — so a test can
  /// prove the three input paths reach the same code.
  @visibleForTesting
  final ValueChanged<RiverMove>? onMove;

  @override
  State<RiverRescueGame> createState() => _RiverRescueGameState();
}

/// Everything the child can ask the basket to do.
enum RiverMove { laneLeft, laneRight, laneCenter, hop, duck, boost }

enum _Phase { stageIntro, running, arriving, stageCleared, finished }

/// A vertical move in progress. Hop and duck are states the basket passes
/// through, not lanes of their own — there is nowhere to get stuck.
enum _Vertical { none, hop, duck }

class _RiverRescueGameState extends State<RiverRescueGame>
    with SingleTickerProviderStateMixin {
  // Feel constants. Lane changes are slow enough to read and fast enough to
  // save you; both hop and duck outlast the window in which they are needed.
  static const double _laneSwitchSeconds = 0.18;
  static const double _verticalSeconds = 0.35;
  static const double _stageIntroSeconds = 2.2;
  static const double _arrivalSeconds = 3.0;

  /// Grace after a bump. Without it one wide hazard can take every heart in a
  /// single frame-run, which reads as the game cheating.
  static const double _immunitySeconds = 0.9;

  /// How far off a lane's centre the basket can be and still count as in it.
  /// Below half a lane on purpose: mid-switch, the child slips past.
  static const double _laneHitWindow = 0.45;

  late final Ticker _ticker;
  late final TextToSpeechService _tts;
  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;

  /// Bumped once per frame rather than calling setState from the tick, so the
  /// scene repaints without rebuilding the HUD sixty times a second.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;
  double _clock = 0;

  _Phase _phase = _Phase.stageIntro;
  double _phaseTimer = _stageIntroSeconds;

  int _stageIndex = 0;
  double _travelled = 0;

  /// Metres cleared in stages already finished — the running-total "score" a
  /// runner-style HUD shows, distinct from `_travelled` which resets each stage.
  double _completedDistance = 0;
  double get _totalTravelled => _completedDistance + _travelled;

  int _hearts = kRiverStartingHearts;
  int _lotusCollected = 0;

  // Lane position, as a continuous 0..2 so a switch can tween.
  RiverLane _lane = RiverLane.center;
  double _laneFrom = 1;
  double _laneT = 1;

  _Vertical _vertical = _Vertical.none;
  double _verticalT = 0;

  double _shield = 0;
  double _boost = 0;
  bool _boostUsed = false;
  double _immunity = 0;
  double _bump = 0;

  /// Seconds left of the baby's crying face after a heart is lost. Longer
  /// than [_bump] on purpose — the splash reads instantly, but a face needs
  /// more than half a second on screen to actually register as an expression.
  static const double _cryFadeSeconds = 2.6;
  double _cry = 0;

  /// A brief reassurance shown after a heart is lost or a stage's hearts
  /// refill — "you still have a chance" said out loud rather than left to be
  /// inferred from the HUD, which a child mid-swipe is not looking at.
  String? _toastText;
  double _toastTimer = 0;
  static const double _toastSeconds = 2.4;

  /// Indices already dealt with in the current stage, so nothing is collected
  /// or collided with twice.
  final Set<int> _passedObstacles = <int>{};
  final Set<int> _takenLotuses = <int>{};
  final Set<int> _takenBlessings = <int>{};
  final Set<int> _startled = <int>{};

  List<RiverStage> get _stages => widget.definition.riverStages;
  RiverStage get _stage => _stages[_stageIndex];

  int get _lotusTotal =>
      _stages.fold(0, (int sum, RiverStage s) => sum + s.lotuses.length);

  @override
  void initState() {
    super.initState();
    _tts = context.read<TextToSpeechService>();
    _audio.startCreationAmbience(track: KidsZoneBgm.interesting);
    _ticker = createTicker(_onTick)..start();
    _speak(_stage.cue);
    // The river is meant to fill the screen the way a runner does — status
    // and navigation bars are chrome the game does not have room for.
    // Restored in dispose so the rest of the app is unaffected.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ticker.dispose();
    _frame.dispose();
    _tts.stop();
    _audio.stopAmbience();
    super.dispose();
  }

  /// Narration must never block the river. `speak` returns when speech *starts*
  /// — and hangs outright when no engine is installed — so it is fired and
  /// forgotten, and the game clock is never waiting on it.
  void _speak(String text) {
    unawaited(_tts.speak(text).catchError((Object _) {}));
  }

  // ------------------------------------------------------------------ clock

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    _clock += dt;
    _advanceMoves(dt);

    switch (_phase) {
      case _Phase.stageIntro:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) {
          setState(() => _phase = _Phase.running);
        }
      case _Phase.running:
        _advanceRiver(dt);
      case _Phase.arriving:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) _finishStage();
      case _Phase.stageCleared:
      case _Phase.finished:
        break;
    }

    if (mounted) _frame.value++;
  }

  /// Lane tweens, hop/duck arcs and the timed effects. These keep running
  /// during the arrival beat so a hop already in the air still lands.
  void _advanceMoves(double dt) {
    if (_laneT < 1) {
      _laneT = math.min(1, _laneT + dt / _laneSwitchSeconds);
    }
    if (_vertical != _Vertical.none) {
      _verticalT += dt / _verticalSeconds;
      if (_verticalT >= 1) {
        _verticalT = 0;
        _vertical = _Vertical.none;
      }
    }
    if (_bump > 0) _bump = math.max(0, _bump - dt / 0.45);
    if (_cry > 0) _cry = math.max(0, _cry - dt / _cryFadeSeconds);
    if (_immunity > 0) _immunity = math.max(0, _immunity - dt);
    if (_boost > 0) _boost = math.max(0, _boost - dt);
    if (_shield > 0) {
      final double was = _shield;
      _shield = math.max(0, _shield - dt);
      if (was > 0 && _shield == 0) _audio.playShieldExpire();
    }
    // The toast fades on its own clock, independent of setState — the frame
    // ticker repaints it every tick (see the ValueListenableBuilder around
    // it), so nothing here needs to trigger a full rebuild just to hide it.
    if (_toastTimer > 0) {
      _toastTimer = math.max(0, _toastTimer - dt);
      if (_toastTimer == 0) _toastText = null;
    }
  }

  void _advanceRiver(double dt) {
    final double speed =
        _stage.speedAt(_travelled) * (_boost > 0 ? kRiverBoostFactor : 1);
    _travelled += speed * dt;

    _collect();
    _collide();

    if (_travelled >= _stage.length) {
      setState(() {
        _phase = _Phase.arriving;
        _phaseTimer = _arrivalSeconds;
      });
      _audio.pauseForSpeech();
      _speak(_stage.arrivalNarration);
      SemanticsService.announce(
          _stage.arrivalNarration, Directionality.of(context));
    }
  }

  /// True when the basket is close enough to [lane] to interact with it.
  bool _inLane(RiverLane lane) =>
      (_laneOffset - lane.index).abs() < _laneHitWindow;

  void _collect() {
    for (int i = 0; i < _stage.lotuses.length; i++) {
      if (_takenLotuses.contains(i)) continue;
      final RiverLotus lotus = _stage.lotuses[i];
      if (lotus.distance > _travelled) continue;
      _takenLotuses.add(i);
      if (_inLane(lotus.lane)) {
        _lotusCollected++;
        _audio.playLotus();
      }
    }

    for (int i = 0; i < _stage.blessings.length; i++) {
      if (_takenBlessings.contains(i)) continue;
      final AngelBlessing blessing = _stage.blessings[i];
      if (blessing.distance > _travelled) continue;
      _takenBlessings.add(i);
      if (_inLane(blessing.lane)) {
        _shield = kRiverBlessingSeconds;
        _audio.playBlessing();
        SemanticsService.announce(
          AppLocalizations.of(context).kidsZoneRiverBlessingTaken,
          Directionality.of(context),
        );
      }
    }
  }

  void _collide() {
    for (int i = 0; i < _stage.obstacles.length; i++) {
      if (_passedObstacles.contains(i)) continue;
      final RiverSpawn spawn = _stage.obstacles[i];
      if (spawn.distance > _travelled) continue;
      _passedObstacles.add(i);
      if (!_inLane(spawn.lane)) continue;
      if (_clearedBy(spawn.kind)) continue;

      // Shielded, boosting, or still shaking off the last bump: the hazard is
      // survived without a heart. The shield is spent; the boost is not.
      if (_shield > 0) {
        _shield = 0;
        _bump = 0.6;
        _audio.playShieldExpire();
        continue;
      }
      if (_boost > 0 || _immunity > 0) continue;

      _registerBump(i, spawn);
    }
  }

  /// Whether the move currently in progress answers this hazard.
  bool _clearedBy(RiverObstacleKind kind) => switch (kind.response) {
        RiverResponse.hop => _vertical == _Vertical.hop,
        RiverResponse.duck => _vertical == _Vertical.duck,
        // Reeds and crocodiles are whole-lane hazards. Hopping or ducking is
        // never an answer — steering is the only one, which is what keeps the
        // crocodile something to go around rather than something to jump on.
        RiverResponse.switchLane => false,
      };

  void _registerBump(int index, RiverSpawn spawn) {
    _hearts = math.max(0, _hearts - 1);
    _bump = 1;
    _cry = 1;
    _immunity = _immunitySeconds;
    if (spawn.kind == RiverObstacleKind.sleepyCrocodile) {
      _startled.add(index);
    }
    _audio.playBump();
    // A splash and a wobble already say "something happened"; this says
    // "and you can keep going" — the retry-not-loss rule stated in words,
    // not left for the child to infer from the hearts still not being zero.
    _toastText = AppLocalizations.of(context).kidsZoneRiverBumpToast(_hearts);
    _toastTimer = _toastSeconds;
    setState(() {});
  }

  // ------------------------------------------------------------------ moves

  void _apply(RiverMove move) {
    widget.onMove?.call(move);
    if (_phase != _Phase.running) return;

    switch (move) {
      case RiverMove.laneLeft:
        _moveTo(_lane.shifted(-1));
      case RiverMove.laneRight:
        _moveTo(_lane.shifted(1));
      case RiverMove.laneCenter:
        _moveTo(RiverLane.center);
      case RiverMove.hop:
        _startVertical(_Vertical.hop);
      case RiverMove.duck:
        _startVertical(_Vertical.duck);
      case RiverMove.boost:
        _paddleBoost();
    }
  }

  void _moveTo(RiverLane? target) {
    if (target == null || target == _lane) return;
    setState(() {
      _laneFrom = _laneOffset;
      _lane = target;
      _laneT = 0;
    });
    _audio.playLaneSwitch();
  }

  void _startVertical(_Vertical next) {
    // A move already under way is not restarted; spamming the button must not
    // extend an arc into a permanent state.
    if (_vertical != _Vertical.none) return;
    setState(() {
      _vertical = next;
      _verticalT = 0;
    });
    next == _Vertical.hop ? _audio.playHop() : _audio.playDuck();
  }

  /// One burst per stage. It shields for its whole duration, so choosing to use
  /// it can never cost a heart — a boost that could backfire would be a trap.
  void _paddleBoost() {
    if (_boostUsed) return;
    setState(() {
      _boostUsed = true;
      _boost = kRiverBoostSeconds;
    });
    _audio.playBlessing();
  }

  // ------------------------------------------------------------- stage flow

  void _finishStage() {
    _audio.resumeAfterSpeech();
    if (_stageIndex + 1 >= _stages.length) {
      setState(() => _phase = _Phase.finished);
      return;
    }
    setState(() => _phase = _Phase.stageCleared);
  }

  void _nextStage() {
    setState(() {
      _completedDistance += _stage.length;
      _stageIndex++;
      _travelled = 0;
      // Hearts refill: each stretch of river is a fresh chance, and the last
      // one is what the star rating reads.
      _hearts = kRiverStartingHearts;
      _boostUsed = false;
      _boost = 0;
      _shield = 0;
      _immunity = 0;
      _bump = 0;
      _cry = 0;
      _lane = RiverLane.center;
      _laneFrom = 1;
      _laneT = 1;
      _vertical = _Vertical.none;
      _passedObstacles.clear();
      _takenLotuses.clear();
      _takenBlessings.clear();
      _startled.clear();
      _phase = _Phase.stageIntro;
      _phaseTimer = _stageIntroSeconds;
      // The literal "new chance": a spent set of hearts is whole again for
      // the stretch ahead, and the child is told so rather than left to
      // notice the HUD refilled on its own.
      _toastText = AppLocalizations.of(context).kidsZoneRiverFreshChanceToast;
      _toastTimer = _toastSeconds;
    });
    _speak(_stage.cue);
  }

  int get _stars => riverRescueStars(
        heartsRemaining: _hearts,
        lotusCollected: _lotusCollected,
        lotusAvailable: _lotusTotal,
      );

  void _finish() {
    _audio.stopAmbience();
    widget.onComplete(_stars);
  }

  // ------------------------------------------------------------------- view

  /// Continuous lane position, 0 (left) to 2 (right).
  double get _laneOffset {
    final double t = Curves.easeOutCubic.transform(_laneT.clamp(0.0, 1.0));
    return _laneFrom + (_lane.index - _laneFrom) * t;
  }

  /// Hop height / duck depth, 0 at the ends of the arc and 1 in the middle.
  double get _verticalAmount =>
      _vertical == _Vertical.none ? 0 : math.sin(_verticalT * math.pi);

  /// How fast the river feels right now, 0 (stopped) to past 1 (boosting).
  /// Drives the speed-streak intensity in the backdrop — the one purely
  /// cosmetic signal that says "this is getting fast" the way an endless
  /// runner's screen edges blur on a sprint.
  double get _speedFactor {
    if (_phase != _Phase.running) return 0;
    final double speed =
        _stage.speedAt(_travelled) * (_boost > 0 ? kRiverBoostFactor : 1);
    return (speed / _stage.endSpeed).clamp(0.0, 1.4);
  }

  List<RiverEntityView> _visibleEntities() {
    final List<RiverEntityView> out = <RiverEntityView>[];
    const double depth = RiverPerspective.viewDepth;

    for (int i = 0; i < _stage.obstacles.length; i++) {
      final RiverSpawn s = _stage.obstacles[i];
      final double ahead = s.distance - _travelled;
      if (ahead < -1.5 || ahead > depth) continue;
      out.add(RiverEntityView(
        lane: s.lane,
        depth: (ahead / depth).clamp(0.0, 1.0),
        kind: s.kind,
        startled: _startled.contains(i),
      ));
    }
    for (int i = 0; i < _stage.lotuses.length; i++) {
      if (_takenLotuses.contains(i)) continue;
      final RiverLotus l = _stage.lotuses[i];
      final double ahead = l.distance - _travelled;
      if (ahead < 0 || ahead > depth) continue;
      out.add(RiverEntityView(
        lane: l.lane,
        depth: (ahead / depth).clamp(0.0, 1.0),
        kind: null,
        lotus: true,
      ));
    }
    for (int i = 0; i < _stage.blessings.length; i++) {
      if (_takenBlessings.contains(i)) continue;
      final AngelBlessing b = _stage.blessings[i];
      final double ahead = b.distance - _travelled;
      if (ahead < 0 || ahead > depth) continue;
      out.add(RiverEntityView(
        lane: b.lane,
        depth: (ahead / depth).clamp(0.0, 1.0),
        kind: null,
        blessing: true,
      ));
    }
    return out;
  }

  void _exit() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (_stages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.stopTitle)),
        body: EmptyView(
          message: l10n.kidsZoneGameMissing,
          icon: Icons.extension_off_rounded,
          actionLabel: l10n.actionClose,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    // TalkBack swallows one-finger swipes before they reach the app, so a
    // gesture-only runner is unplayable with a screen reader on. The buttons
    // are the whole control scheme in that mode, not a hint layer over it.
    final bool accessible = MediaQuery.of(context).accessibleNavigation;

    // Full-bleed, no app bar, no instruction card: the river fills the whole
    // screen the way an endless runner does, and the HUD, controls and back
    // button float over it instead of squeezing it into a shorter box. The
    // scene itself has no SafeArea padding — it should run edge to edge —
    // only the interactive chrome on top of it keeps clear of notches.
    return Scaffold(
      backgroundColor: MosesColors.waterDeep,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (BuildContext context, _, __) {
                return RiverSceneView(
                  travelled: _travelled,
                  phase: _clock,
                  entities: _visibleEntities(),
                  speedFactor: _speedFactor,
                  arrival: _phase == _Phase.arriving
                      ? 1 - (_phaseTimer / _arrivalSeconds)
                      : 0,
                  basket: RiverBasketView(
                    laneOffset: _laneOffset,
                    hop: _vertical == _Vertical.hop ? _verticalAmount : 0,
                    duck: _vertical == _Vertical.duck ? _verticalAmount : 0,
                    tilt: (_lane.index - _laneOffset) * 0.28,
                    shielded: _shield > 0 || _boost > 0,
                    bump: _bump,
                    cry: _cry,
                  ),
                );
              },
            ),
          ),
          if (!accessible)
            Positioned.fill(
              child: _RiverGestureLayer(
                enabled: _phase == _Phase.running,
                onMove: _apply,
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _RiverExitButton(onPressed: _exit),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _RiverHud(
                          distanceMetres: _totalTravelled.round(),
                          hearts: _hearts,
                          lotusCollected: _lotusCollected,
                          lotusTotal: _lotusTotal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_shield > 0 || _boost > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _ShieldBanner(
                      label: _boost > 0
                          ? l10n.kidsZoneRiverBoosting
                          : l10n.kidsZoneRiverShielded,
                    ),
                  ),
                // Ticks with the frame notifier rather than needing its own
                // setState — the toast's own clock decides when it hides, and
                // this just has to notice on the next painted frame.
                ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (BuildContext context, _, __) {
                    if (_toastText == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _RiverToast(
                        text: _toastText!,
                        opacity: _toastTimer > 0.5
                            ? 1.0
                            : (_toastTimer / 0.5).clamp(0.0, 1.0),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: _RiverControls(
                    accessible: accessible,
                    enabled: _phase == _Phase.running,
                    boostAvailable: !_boostUsed,
                    lane: _lane,
                    onMove: _apply,
                  ),
                ),
              ],
            ),
          ),
          if (_phase != _Phase.running)
            Positioned.fill(
              child: _RiverPhaseOverlay(
                phase: _phase,
                stage: _stage,
                stageNumber: _stageIndex + 1,
                stageCount: _stages.length,
                stars: _stars,
                onNext: _nextStage,
                onFinish: _finish,
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- input

/// Swipes over the river, with the tap thirds as the always-available fallback.
///
/// Built on raw `Listener` pointer events rather than `GestureDetector`'s
/// `onPanEnd` + `onTapUp` together — those are two separate recognisers
/// competing in the same gesture arena, and a child's swipe is often slow and
/// short enough that the pan recogniser never reaches a firing velocity while
/// the tap recogniser has already lost to the movement. The result was swipes
/// that visibly happened on screen and did nothing. Tracking the raw drag
/// ourselves fires the move the instant it crosses a distance threshold —
/// no velocity, no waiting for release — which is both more forgiving of a
/// slow swipe and more responsive for a fast one.
class _RiverGestureLayer extends StatelessWidget {
  const _RiverGestureLayer({required this.enabled, required this.onMove});

  final bool enabled;
  final ValueChanged<RiverMove> onMove;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return _RiverGestureTracker(
          size: Size(c.maxWidth, c.maxHeight),
          onMove: onMove,
        );
      },
    );
  }
}

class _RiverGestureTracker extends StatefulWidget {
  const _RiverGestureTracker({required this.size, required this.onMove});

  final Size size;
  final ValueChanged<RiverMove> onMove;

  @override
  State<_RiverGestureTracker> createState() => _RiverGestureTrackerState();
}

class _RiverGestureTrackerState extends State<_RiverGestureTracker> {
  Offset? _start;
  bool _fired = false;

  /// Distance a drag must cover before it counts as a swipe rather than a tap.
  /// A fraction of the shorter side, so it scales with the device instead of
  /// demanding the same finger-travel on a small phone as a tablet.
  double get _threshold =>
      math.min(widget.size.width, widget.size.height) * 0.055;

  void _onDown(PointerDownEvent event) {
    _start = event.localPosition;
    _fired = false;
  }

  void _onMove(PointerMoveEvent event) {
    final Offset? start = _start;
    if (start == null || _fired) return;

    final double dx = event.localPosition.dx - start.dx;
    final double dy = event.localPosition.dy - start.dy;
    final double threshold = _threshold;

    if (dx.abs() > threshold && dx.abs() > dy.abs()) {
      _fired = true;
      widget.onMove(dx < 0 ? RiverMove.laneLeft : RiverMove.laneRight);
    } else if (dy.abs() > threshold && dy.abs() >= dx.abs()) {
      _fired = true;
      widget.onMove(dy < 0 ? RiverMove.hop : RiverMove.duck);
    }
  }

  void _onUp(PointerUpEvent event) {
    // No threshold was crossed: this was a tap, not a swipe. Outer thirds
    // steer one lane; the middle third is the paddle boost. The centre lane
    // is still reachable by tapping back the other way, so no lane is locked
    // behind the gesture-only path.
    if (!_fired && _start != null) {
      final double x = _start!.dx / widget.size.width;
      if (x < 1 / 3) {
        widget.onMove(RiverMove.laneLeft);
      } else if (x > 2 / 3) {
        widget.onMove(RiverMove.laneRight);
      } else {
        widget.onMove(RiverMove.boost);
      }
    }
    _start = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _start = null,
      child: const SizedBox.expand(),
    );
  }
}

/// The button bar under the river.
///
/// Always present — Hop, Boost and Duck have no swipe-free equivalent
/// otherwise. With a screen reader on it widens to carry lane buttons too, so
/// the whole game is reachable without a single gesture.
class _RiverControls extends StatelessWidget {
  const _RiverControls({
    required this.accessible,
    required this.enabled,
    required this.boostAvailable,
    required this.lane,
    required this.onMove,
  });

  final bool accessible;
  final bool enabled;
  final bool boostAvailable;
  final RiverLane lane;
  final ValueChanged<RiverMove> onMove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accessible) ...<Widget>[
          Row(
            children: <Widget>[
              _RiverButton(
                label: l10n.kidsZoneRiverLaneLeft,
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled && lane != RiverLane.left,
                selected: lane == RiverLane.left,
                onPressed: () => onMove(RiverMove.laneLeft),
              ),
              _RiverButton(
                label: l10n.kidsZoneRiverLaneCenter,
                icon: Icons.keyboard_arrow_up_rounded,
                enabled: enabled && lane != RiverLane.center,
                selected: lane == RiverLane.center,
                onPressed: () => onMove(RiverMove.laneCenter),
              ),
              _RiverButton(
                label: l10n.kidsZoneRiverLaneRight,
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled && lane != RiverLane.right,
                selected: lane == RiverLane.right,
                onPressed: () => onMove(RiverMove.laneRight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: <Widget>[
            _RiverButton(
              label: l10n.kidsZoneRiverHop,
              icon: Icons.arrow_upward_rounded,
              enabled: enabled,
              onPressed: () => onMove(RiverMove.hop),
            ),
            _RiverButton(
              label: l10n.kidsZoneRiverBoost,
              icon: Icons.rowing_rounded,
              enabled: enabled && boostAvailable,
              onPressed: () => onMove(RiverMove.boost),
            ),
            _RiverButton(
              label: l10n.kidsZoneRiverDuck,
              icon: Icons.arrow_downward_rounded,
              enabled: enabled,
              onPressed: () => onMove(RiverMove.duck),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiverButton extends StatelessWidget {
  const _RiverButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          enabled: enabled,
          selected: selected,
          label: label,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: selected
                      ? MosesColors.reed
                      : MosesColors.water.withOpacity(0.88),
                  disabledBackgroundColor: MosesColors.water.withOpacity(0.25),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // The control is a fixed tap target sized for a thumb, so its
                // icon and caption scale down inside it rather than pushing it
                // taller. Shrinking a button a child is aiming at would be the
                // worse trade.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(icon, size: 20),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KidsZoneText.nunito(
                          size: 10,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- HUD

/// Floats over the river rather than sitting on a solid bar, so it needs its
/// own translucent backing to stay readable against whatever the scene is
/// doing underneath — a bright sky in one stage, dark water in the next.
/// The persistent runner HUD — deliberately down to three numbers (distance,
/// lotuses, hearts). "Stage X of Y" already gets said out loud and shown at
/// full size on the stage-intro and stage-cleared cards; repeating it in a
/// cramped top pill during play would be the one piece of chrome with nothing
/// to actually do while the child is looking at the river, not the HUD.
class _RiverHud extends StatelessWidget {
  const _RiverHud({
    required this.distanceMetres,
    required this.hearts,
    required this.lotusCollected,
    required this.lotusTotal,
  });

  final int distanceMetres;
  final int hearts;
  final int lotusCollected;
  final int lotusTotal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          // The running distance is the closest thing this level has to a
          // score — the number that keeps climbing is what makes a runner
          // feel like a runner rather than a fixed obstacle course.
          Semantics(
            label: l10n.kidsZoneRiverDistance(distanceMetres),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.waves_rounded,
                      size: 15, color: MosesColors.foam),
                  const SizedBox(width: 3),
                  Text(
                    '${distanceMetres}m',
                    style: KidsZoneText.nunito(
                        size: 14, weight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Semantics(
            label: l10n.kidsZoneRiverLotusCount(lotusCollected, lotusTotal),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.local_florist_rounded,
                      size: 16, color: MosesColors.lotus),
                  const SizedBox(width: 3),
                  Text(
                    '$lotusCollected',
                    style: KidsZoneText.nunito(
                        size: 13, weight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: l10n.kidsZoneRiverHeartsLeft(hearts),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(kRiverStartingHearts, (int i) {
                  return Icon(
                    i < hearts
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 16,
                    color: MosesColors.heart,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small translucent circle, top-left, the way a runner's pause/exit button
/// sits clear of the action instead of interrupting the full-bleed scene.
class _RiverExitButton extends StatelessWidget {
  const _RiverExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.kidsZoneRiverExit,
      child: Material(
        color: Colors.black.withOpacity(0.32),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.close_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ShieldBanner extends StatelessWidget {
  const _ShieldBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
        decoration: BoxDecoration(
          color: MosesColors.blessing.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: KidsZoneText.nunito(
            size: 12,
            weight: FontWeight.w800,
            color: MosesColors.ink,
          ),
        ),
      ),
    );
  }
}

/// A brief, non-blocking reassurance — "you still have a chance" — shown after
/// a heart is lost or a stage's hearts refill. `IgnorePointer` because it must
/// never be the thing a swipe accidentally lands on.
class _RiverToast extends StatelessWidget {
  const _RiverToast({required this.text, required this.opacity});

  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: KidsZoneText.nunito(
                  size: 13,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ overlays

class _RiverPhaseOverlay extends StatelessWidget {
  const _RiverPhaseOverlay({
    required this.phase,
    required this.stage,
    required this.stageNumber,
    required this.stageCount,
    required this.stars,
    required this.onNext,
    required this.onFinish,
  });

  final _Phase phase;
  final RiverStage stage;
  final int stageNumber;
  final int stageCount;
  final int stars;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    // The arrival beat carries the story, so it is shown over the scene with no
    // button at all — a stray tap must not skip the princess.
    if (phase == _Phase.arriving) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              stage.arrivalNarration,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 14,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    final (String title, String body, String action, VoidCallback press) =
        switch (phase) {
      _Phase.stageIntro => (
          stage.title,
          stage.cue,
          '',
          onNext,
        ),
      _Phase.stageCleared => (
          l10n.kidsZoneRiverStageDone,
          l10n.kidsZoneRiverStageDoneBody(stageNumber, stageCount),
          l10n.kidsZoneRiverNextStage,
          onNext,
        ),
      _Phase.finished => (
          l10n.kidsZoneRiverDoneTitle,
          l10n.kidsZoneRiverDoneBody,
          l10n.kidsZoneRiverCollectStars,
          onFinish,
        ),
      _ => ('', '', '', onNext),
    };

    return Container(
      color: Colors.black.withOpacity(0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (phase == _Phase.finished)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                3,
                (int i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 34,
                  color: KidsZoneColors.star,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 20,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 14,
              weight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          if (action.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: press,
              style: FilledButton.styleFrom(
                backgroundColor: MosesColors.reed,
                foregroundColor: Colors.white,
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}
