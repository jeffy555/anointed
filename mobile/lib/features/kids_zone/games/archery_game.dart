import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';
import '../widgets/battlefield_view.dart';

/// Battle of Siddim archery rounds — drag to aim, release to shoot.
///
/// Soldiers weave down the valley toward Abram's camp; an arrow turns one back.
/// Rounds escalate inside a single stop, ending in the King's Round when the
/// stop's waves include [ArcheryWave.isKingRound].
class ArcheryGame extends StatefulWidget {
  const ArcheryGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
    this.onShot,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  /// Fired whenever an arrow actually leaves the bow, carrying the running shot
  /// count. A seam for verifying that stray touches do not cost arrows.
  @visibleForTesting
  final ValueChanged<int>? onShot;

  @override
  State<ArcheryGame> createState() => _ArcheryGameState();
}

enum _Phase { interlude, roundIntro, playing, roundCleared, breached, victory }

class _ArcheryGameState extends State<ArcheryGame>
    with SingleTickerProviderStateMixin {
  // Field geometry, in fractions of the play area.
  static const Offset _bowAnchor = Offset(0.5, 0.88);
  static const double _campLine = 0.80;
  static const double _spawnLine = 0.06;
  static const int _startingCourage = 3;
  static const int _maxArrowsInFlight = 3;
  static const Duration _shotCooldown = Duration(milliseconds: 220);
  static const double _roundIntroSeconds = 2.4;

  /// A shot inside this multiple of the hitbox counts as a near miss.
  static const double _nearMissFactor = 1.5;

  /// How long the world slows after an arrow strikes the king's shield.
  static const double _slowMoSeconds = 0.45;

  /// Minimum time a between-rounds story beat stays on screen.
  static const double _interludeSeconds = 3.0;

  /// How far the finger must travel before the bow arms. Below this a touch is
  /// exploration, not a shot.
  static const double _armThreshold = 30;

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  final math.Random _random = math.Random();
  final List<_Soldier> _soldiers = <_Soldier>[];
  final List<_Arrow> _arrows = <_Arrow>[];
  final List<_Puff> _puffs = <_Puff>[];

  late final Ticker _ticker;

  Size _field = Size.zero;
  Duration _lastTick = Duration.zero;
  double _clock = 0;

  _Phase _phase = _Phase.roundIntro;
  int _waveIndex = 0;
  int _spawned = 0;
  int _resolved = 0;
  double _spawnTimer = 0;

  int _courage = _startingCourage;
  int _score = 0;
  int _shots = 0;
  int _hits = 0;
  int _breaches = 0;

  /// Soldiers actually turned back across the whole stop.
  int _turnedBack = 0;

  Offset? _aim;
  Offset? _panStart;
  bool _armed = false;
  double _shotCooldownLeft = 0;
  double _phaseTimer = _roundIntroSeconds;

  /// 1 → 0 decay driving the camera shake after a shield strike.
  double _shake = 0;

  /// Seconds of slow motion left.
  double _slowMo = 0;

  late final TextToSpeechService _tts;

  /// Drives the field repaint without rebuilding the surrounding chrome.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  _HudSnapshot _hud = const _HudSnapshot(0, 0, _startingCourage, 0, _Phase.roundIntro);

  List<ArcheryWave> get _waves => widget.definition.archeryWaves;

  ArcheryWave get _wave => _waves[_waveIndex];

  bool get _isFinalWave => _waveIndex >= _waves.length - 1;

  @override
  void initState() {
    super.initState();
    // Captured here — resolving it in dispose() is invalid once unmounting.
    _tts = context.read<TextToSpeechService>();
    _audio.startCreationAmbience(track: _trackForStop());
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRound());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _tts.stop();
    _audio.stopAmbience();
    super.dispose();
  }

  KidsZoneBgm _trackForStop() {
    if (_waves.any((ArcheryWave w) => w.isKingRound)) return KidsZoneBgm.thrilling;
    return _waves.first.round <= 2 ? KidsZoneBgm.interesting : KidsZoneBgm.funky;
  }

  // ---------------------------------------------------------------- game loop

  void _onTick(Duration elapsed) {
    final double real =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (real <= 0 || _field.isEmpty) return;

    // Slow motion after a shield strike, so the hit lands visually.
    _slowMo = math.max(0, _slowMo - real);
    final double dt = _slowMo > 0 ? real * 0.35 : real;

    _clock += dt;
    _shotCooldownLeft = math.max(0, _shotCooldownLeft - dt);
    _shake = math.max(0, _shake - real * 3.2);

    switch (_phase) {
      // The story beat between rounds holds until its narration is done.
      case _Phase.interlude:
        _phaseTimer -= real;
        if (_phaseTimer <= 0 && !_tts.isSpeaking) _startRound();
      case _Phase.roundIntro:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) _startRound();
      case _Phase.playing:
        _advancePlay(dt);
      case _Phase.roundCleared:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) _advanceRound();
      case _Phase.breached:
      case _Phase.victory:
        _advanceEffects(dt);
    }

    if (!mounted) return;
    _frame.value++;

    // Only rebuild the widget tree when something the HUD or an overlay shows
    // has actually changed.
    final _HudSnapshot next = _HudSnapshot(
      _waveIndex,
      _score,
      _courage,
      math.max(0, _wave.soldierCount - _resolved),
      _phase,
    );
    if (next != _hud) setState(() => _hud = next);
  }

  void _advancePlay(double dt) {
    _advanceSpawning(dt);
    _advanceSoldiers(dt);
    _advanceArrows(dt);
    _advanceEffects(dt);
    _resolveHits();

    if (_phase == _Phase.playing &&
        _resolved >= _wave.soldierCount &&
        _soldiers.isEmpty) {
      _clearRound();
    }
  }

  void _advanceSpawning(double dt) {
    if (_spawned >= _wave.soldierCount) return;
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;
    _spawnTimer = _wave.spawnInterval;
    _spawnSoldier();
  }

  void _spawnSoldier() {
    // In the King's Round the guards come first so the king is the climax.
    final bool isKing = _wave.isKingRound && _spawned == _wave.soldierCount - 1;
    final double startX = 0.15 + _random.nextDouble() * 0.7;

    _soldiers.add(
      _Soldier(
        x: startX,
        y: _spawnLine,
        baseX: startX,
        drift: (_random.nextBool() ? 1 : -1) * (0.03 + _random.nextDouble() * 0.05),
        phase: _random.nextDouble() * math.pi * 2,
        bornAt: _clock,
        isKing: isKing,
        hitsLeft: isKing ? _wave.hitsToTurnBack : 1,
      ),
    );
    _spawned += 1;
  }

  void _advanceSoldiers(double dt) {
    final List<_Soldier> breached = <_Soldier>[];

    for (final _Soldier soldier in _soldiers) {
      if (soldier.retreating) {
        soldier.y -= dt * 0.55;
        soldier.opacity = math.max(0, soldier.opacity - dt * 1.8);
        continue;
      }

      final double speed = soldier.isKing ? _wave.speed * 0.85 : _wave.speed;
      soldier.y += dt * speed;
      soldier.age += dt;

      final double weave = math.sin(
            (soldier.age / _wave.zigzagPeriod) * math.pi * 2 + soldier.phase,
          ) *
          _wave.zigzagAmplitude;
      soldier.x = (soldier.baseX + soldier.drift * soldier.age + weave)
          .clamp(0.08, 0.92);
      soldier.flash = math.max(0, soldier.flash - dt * 4);
      soldier.flinch = math.max(0, soldier.flinch - dt * 3.5);

      if (soldier.y >= _campLine) breached.add(soldier);
    }

    for (final _Soldier soldier in breached) {
      _soldiers.remove(soldier);
      _onBreach();
    }

    _soldiers.removeWhere((_Soldier s) => s.retreating && s.opacity <= 0);
  }

  void _advanceArrows(double dt) {
    for (final _Arrow arrow in _arrows) {
      arrow.x += arrow.vx * dt;
      arrow.y += arrow.vy * dt;
      arrow.trail.insert(0, Offset(arrow.x, arrow.y));
      if (arrow.trail.length > 6) arrow.trail.removeLast();
    }
    _arrows.removeWhere(
      (_Arrow a) => a.y < -0.08 || a.y > 1.08 || a.x < -0.08 || a.x > 1.08,
    );
  }

  void _advanceEffects(double dt) {
    for (final _Puff puff in _puffs) {
      puff.t += dt;
    }
    _puffs.removeWhere((_Puff p) => p.t >= p.duration);
  }

  void _resolveHits() {
    final double shortSide = math.min(_field.width, _field.height);
    final List<_Arrow> spent = <_Arrow>[];

    for (final _Arrow arrow in _arrows) {
      _Soldier? grazedBy;

      for (final _Soldier soldier in _soldiers) {
        if (soldier.retreating) continue;

        final double radius =
            _wave.hitRadius * shortSide * (soldier.isKing ? 1.0 : 1.25);
        final double dx = (arrow.x - soldier.x) * _field.width;
        final double dy = (arrow.y - soldier.y) * _field.height;
        final double distanceSq = dx * dx + dy * dy;

        if (distanceSq <= radius * radius) {
          spent.add(arrow);
          _registerHit(soldier);
          grazedBy = null;
          break;
        }

        // Just outside the hitbox: worth telling the child it was close, so a
        // shrinking target reads as demanding rather than arbitrary.
        final double nearRadius = radius * _nearMissFactor;
        if (distanceSq <= nearRadius * nearRadius) grazedBy = soldier;
      }

      if (grazedBy != null && !arrow.grazed) _registerNearMiss(arrow, grazedBy);
    }

    _arrows.removeWhere(spent.contains);
  }

  /// An arrow that passed close enough to matter. Costs nothing — it only
  /// teaches.
  void _registerNearMiss(_Arrow arrow, _Soldier soldier) {
    arrow.grazed = true;
    soldier.flinch = 1;
    _puffs.add(
      _Puff(x: soldier.x, y: soldier.y, kind: _PuffKind.nearMiss),
    );
    _audio.playSparkle();
  }

  void _registerHit(_Soldier soldier) {
    _hits += 1;
    soldier.hitsLeft -= 1;
    soldier.flash = 1;

    // Accuracy points plus a bonus for turning a soldier back quickly.
    final double reaction = _clock - soldier.bornAt;
    final int speedBonus = (60 * (1 - (reaction / 4.5)).clamp(0.0, 1.0)).round();
    _score += (soldier.isKing ? 150 : 100) + speedBonus;

    // The king is the climax of the adventure, so landing one on his shield has
    // to feel different from turning back a foot soldier: sparks fly, the
    // valley shakes, and the world briefly slows.
    if (soldier.isKing) {
      _puffs.add(
        _Puff(x: soldier.x, y: soldier.y, kind: _PuffKind.shieldSpark),
      );
      _shake = 1;
      _slowMo = _slowMoSeconds;
      _audio.playCelebrate();
    }

    if (soldier.hitsLeft > 0) {
      if (!soldier.isKing) _audio.playSparkle();
      return;
    }

    soldier.retreating = true;
    _resolved += 1;
    _turnedBack += 1;
    _puffs.add(_Puff(x: soldier.x, y: soldier.y, isKing: soldier.isKing));
    _audio.playCorrect();
  }

  void _onBreach() {
    if (_phase != _Phase.playing) return;
    _resolved += 1;
    _breaches += 1;
    _courage = math.max(0, _courage - 1);
    _audio.playConnect();

    if (_courage == 0) {
      _phase = _Phase.breached;
      _arrows.clear();
      _soldiers.clear();
      SemanticsService.announce(
        AppLocalizations.of(context).kidsZoneSiddimBreached,
        Directionality.of(context),
      );
    }
  }

  // ------------------------------------------------------------ round control

  /// Opens a round. Rounds after the first are introduced by a spoken story
  /// beat, so the escalation in speed feels like the march pressing on rather
  /// than the game simply getting harder.
  void _openRound() {
    final String line = _wave.interlude;
    if (line.isEmpty) {
      setState(() {
        _phase = _Phase.roundIntro;
        _phaseTimer = _roundIntroSeconds;
      });
      return;
    }

    setState(() {
      _phase = _Phase.interlude;
      _phaseTimer = _interludeSeconds;
    });

    // Gameplay is already halted by the phase, so this is just narration over
    // a still valley; the loop BGM ducks under it.
    _audio.pauseForSpeech();
    unawaited(_tts.speak(line).catchError((Object _) {}));
    SemanticsService.announce(line, Directionality.of(context));
  }

  void _startRound() {
    _audio.resumeAfterSpeech();
    _phase = _Phase.playing;
    _spawnTimer = 0.6;
    SemanticsService.announce(_wave.cue, Directionality.of(context));
  }

  void _clearRound() {
    _arrows.clear();
    _audio.playCelebrate();
    // The last round of any stop ends on a card the child dismisses, so every
    // level gets to show its scorecard — not just the King's Round.
    _phase = _isFinalWave ? _Phase.victory : _Phase.roundCleared;
    _phaseTimer = 2.0;
  }

  void _advanceRound() {
    if (_isFinalWave) {
      _finish();
      return;
    }
    _waveIndex += 1;
    _spawned = 0;
    _resolved = 0;
    _soldiers.clear();
    _puffs.clear();
    _openRound();
  }

  /// Everything the stars are judged on, in one place, so what the child is
  /// shown and what they are scored on cannot drift apart.
  ArcheryScorecard get _scorecard => ArcheryScorecard(
        turnedBack: _turnedBack,
        totalSoldiers: _waves.fold<int>(
          0,
          (int sum, ArcheryWave w) => sum + w.soldierCount,
        ),
        hits: _hits,
        shots: _shots,
        hearts: _courage,
        maxHearts: _startingCourage,
        breaches: _breaches,
        score: _score,
      );

  void _finish() {
    if (!mounted) return;
    _ticker.stop();
    widget.onComplete(_scorecard.stars);
  }

  void _retryRound() {
    setState(() {
      _soldiers.clear();
      _arrows.clear();
      _puffs.clear();
      _spawned = 0;
      _resolved = 0;
      _courage = _startingCourage;
      _phase = _Phase.roundIntro;
      _phaseTimer = _roundIntroSeconds;
    });
  }

  // ----------------------------------------------------------------- shooting

  /// Where the finger went down, so arming can be judged on how far it has
  /// travelled since — not on how far the aim point sits from the bow.
  void _beginAim(Offset localPosition) {
    if (_phase != _Phase.playing || _field.isEmpty) return;
    _panStart = localPosition;
    setState(() {
      _armed = false;
      _aim = null;
    });
  }

  void _updateAim(Offset localPosition) {
    if (_phase != _Phase.playing || _field.isEmpty) return;
    final Offset? start = _panStart;
    final bool armed =
        start != null && (localPosition - start).distance >= _armThreshold;

    if (armed && !_armed) _audio.playSparkle();
    setState(() {
      _armed = armed;
      // The crosshair only appears once the shot is live, so the child can see
      // the difference between exploring and aiming.
      _aim = armed ? localPosition : null;
    });
  }

  /// Fires into one of five fixed lanes across the valley.
  ///
  /// Drag-aim-release on a painted canvas is unreachable with a screen reader
  /// on: TalkBack claims one-finger gestures for its own navigation, so a
  /// custom swipe never arrives. Discrete, focusable controls are the input
  /// that actually works — focus one, double-tap, the arrow flies. It is a
  /// coarser game than aiming freely, but it is a game rather than a wall.
  void _fireLane(double xFraction) {
    if (_phase != _Phase.playing || _field.isEmpty) return;
    if (_shotCooldownLeft > 0 || _arrows.length >= _maxArrowsInFlight) return;

    final Offset origin = Offset(
      _bowAnchor.dx * _field.width,
      _bowAnchor.dy * _field.height,
    );
    final Offset target = Offset(
      xFraction * _field.width,
      _spawnLine * _field.height,
    );
    _launch(target - origin);
  }

  void _release() {
    final Offset? aim = _aim;
    final bool wasArmed = _armed;
    _panStart = null;
    setState(() {
      _aim = null;
      _armed = false;
    });

    // A bare tap never costs an arrow. Young players touch the screen to
    // explore, and a wasted shot for that is a punishment they cannot read.
    if (!wasArmed || aim == null) return;
    if (_phase != _Phase.playing || _field.isEmpty) return;
    if (_shotCooldownLeft > 0 || _arrows.length >= _maxArrowsInFlight) return;

    final Offset origin = Offset(
      _bowAnchor.dx * _field.width,
      _bowAnchor.dy * _field.height,
    );
    _launch(aim - origin);
  }

  /// Sends an arrow from the bow along [delta]. Shared by both input modes so
  /// they cannot drift apart.
  void _launch(Offset delta) {
    if (delta.distance < 12) return;

    final double speed = _field.height * 1.25;
    final Offset unit = delta / delta.distance;

    _arrows.add(
      _Arrow(
        x: _bowAnchor.dx,
        y: _bowAnchor.dy,
        vx: unit.dx * speed / _field.width,
        vy: unit.dy * speed / _field.height,
      ),
    );
    _shots += 1;
    _shotCooldownLeft = _shotCooldown.inMilliseconds / 1000;
    _audio.playShoot();
    widget.onShot?.call(_shots);
  }

  /// Where the nearest advancing soldier is, described for a screen reader.
  String _threatReport(AppLocalizations l10n) {
    _Soldier? nearest;
    for (final _Soldier s in _soldiers) {
      if (s.retreating) continue;
      if (nearest == null || s.y > nearest.y) nearest = s;
    }
    if (nearest == null) return l10n.kidsZoneSiddimThreatNone;
    return l10n.kidsZoneSiddimThreatAt(_laneName(l10n, nearest.x));
  }

  String _laneName(AppLocalizations l10n, double x) {
    if (x < 0.2) return l10n.kidsZoneSiddimLaneFarLeft;
    if (x < 0.4) return l10n.kidsZoneSiddimLaneLeft;
    if (x < 0.6) return l10n.kidsZoneSiddimLaneAhead;
    if (x < 0.8) return l10n.kidsZoneSiddimLaneRight;
    return l10n.kidsZoneSiddimLaneFarRight;
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool accessible = MediaQuery.of(context).accessibleNavigation;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: _wave.cue,
      readAloudText: _wave.cue,
      pauseKidsZoneBgm: true,
      body: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ArcheryHud(
              roundLabel: l10n.kidsZoneSiddimRoundLabel(
                _wave.round,
                _waves.last.round,
              ),
              score: _score,
              courage: _courage,
              maxCourage: _startingCourage,
              remaining:
                  math.max(0, _wave.soldierCount - _resolved),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    _field = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (DragDownDetails d) => _beginAim(d.localPosition),
                      onPanUpdate: (DragUpdateDetails d) =>
                          _updateAim(d.localPosition),
                      onPanEnd: (DragEndDetails _) => _release(),
                      onPanCancel: _release,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: SiddimColors.duskGradient,
                            ),
                          ),
                          CustomPaint(
                            painter: _ArcheryPainter(
                              repaint: _frame,
                              soldiers: _soldiers,
                              arrows: _arrows,
                              puffs: _puffs,
                              aim: _phase == _Phase.playing ? _aim : null,
                              bowAnchor: _bowAnchor,
                              campLine: _campLine,
                              hitRadius: _wave.hitRadius,
                              showRainbow:
                                  _phase == _Phase.victory && _wave.isKingRound,
                              shake: _shake,
                              nearMissLabel: l10n.kidsZoneSiddimNearMiss,
                            ),
                          ),
                          if (_phase != _Phase.playing)
                            _PhaseOverlay(
                              phase: _phase,
                              wave: _wave,
                              score: _score,
                              accuracy: _shots == 0 ? 0 : _hits / _shots,
                              card: _scorecard,
                              onRetry: _retryRound,
                              onFinish: _finish,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // With a screen reader running, swap free aiming for lanes that can
            // actually be focused and activated.
            if (accessible) ...<Widget>[
              Semantics(
                liveRegion: true,
                label: _threatReport(l10n),
                child: Text(
                  _threatReport(l10n),
                  textAlign: TextAlign.center,
                  style: KidsZoneText.nunito(
                    size: 13,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _LaneFireBar(
                enabled: _phase == _Phase.playing,
                onFire: _fireLane,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              accessible
                  ? l10n.kidsZoneSiddimAimHintAccessible
                  : l10n.kidsZoneSiddimAimHint,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 12,
                weight: FontWeight.w700,
                color: KidsZoneColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- entities

class _Soldier {
  _Soldier({
    required this.x,
    required this.y,
    required this.baseX,
    required this.drift,
    required this.phase,
    required this.bornAt,
    required this.isKing,
    required this.hitsLeft,
  });

  final double baseX;
  final double drift;
  final double phase;
  final double bornAt;
  final bool isKing;

  double x;
  double y;
  int hitsLeft;
  double age = 0;
  double flash = 0;

  /// Brief recoil when an arrow whistles past without landing.
  double flinch = 0;
  bool retreating = false;
  double opacity = 1;
}

class _Arrow {
  _Arrow({required this.x, required this.y, required this.vx, required this.vy});

  double x;
  double y;
  final double vx;
  final double vy;
  final List<Offset> trail = <Offset>[];

  /// Only one near-miss reaction per arrow, however long it flies.
  bool grazed = false;
}

/// What a burst of feedback is saying.
enum _PuffKind { turnBack, nearMiss, shieldSpark }

class _Puff {
  _Puff({
    required this.x,
    required this.y,
    this.isKing = false,
    this.kind = _PuffKind.turnBack,
  });

  final double x;
  final double y;
  final bool isKing;
  final _PuffKind kind;
  double t = 0;

  double get duration => switch (kind) {
        _PuffKind.nearMiss => 0.55,
        _PuffKind.shieldSpark => 0.70,
        _PuffKind.turnBack => isKing ? 1.4 : 0.8,
      };

  double get progress => (t / duration).clamp(0.0, 1.0);
}

// -------------------------------------------------------------------- painter

class _ArcheryPainter extends CustomPainter {
  _ArcheryPainter({
    required Listenable repaint,
    required this.soldiers,
    required this.arrows,
    required this.puffs,
    required this.aim,
    required this.bowAnchor,
    required this.campLine,
    required this.hitRadius,
    required this.showRainbow,
    required this.shake,
    required this.nearMissLabel,
  }) : super(repaint: repaint);

  final List<_Soldier> soldiers;
  final List<_Arrow> arrows;
  final List<_Puff> puffs;
  final Offset? aim;
  final Offset bowAnchor;
  final double campLine;
  final double hitRadius;
  final bool showRainbow;

  /// 1 → 0 decay of the camera shake after a strike on the king's shield.
  final double shake;

  /// Localised "Almost!", shown on a near miss.
  final String nearMissLabel;

  @override
  void paint(Canvas canvas, Size size) {
    // A strike on the king rocks the whole valley.
    final bool shaking = shake > 0.01;
    if (shaking) {
      canvas.save();
      final double amount = shake * size.width * 0.012;
      canvas.translate(
        math.sin(shake * 38) * amount,
        math.cos(shake * 31) * amount * 0.6,
      );
    }

    if (showRainbow) paintVictoryRainbow(canvas, size);
    _paintValley(canvas, size);
    for (final _Puff puff in puffs) {
      _paintPuff(canvas, size, puff);
    }
    for (final _Soldier soldier in soldiers) {
      _paintSoldier(canvas, size, soldier);
    }
    for (final _Arrow arrow in arrows) {
      _paintArrow(canvas, size, arrow);
    }
    _paintAbramAndBow(canvas, size);

    if (shaking) canvas.restore();
  }

  /// Canvas text, used sparingly for the near-miss cue.
  void _drawLabel(
    Canvas canvas,
    String text,
    Offset centre,
    Color color,
    double size,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintValley(Canvas canvas, Size size) {
    final double ridgeY = size.height * 0.30;
    final Path ridge = Path()..moveTo(0, ridgeY);
    ridge.quadraticBezierTo(size.width * 0.28, ridgeY - size.height * 0.10,
        size.width * 0.55, ridgeY - size.height * 0.01);
    ridge.quadraticBezierTo(size.width * 0.80, ridgeY + size.height * 0.05,
        size.width, ridgeY - size.height * 0.04);
    ridge.lineTo(size.width, 0);
    ridge.lineTo(0, 0);
    ridge.close();
    canvas.drawPath(
      ridge,
      Paint()..color = SiddimColors.ridgeFar.withOpacity(0.45),
    );

    // Camp ground Abram is defending.
    final Rect camp = Rect.fromLTWH(
      0,
      size.height * campLine,
      size.width,
      size.height * (1 - campLine),
    );
    canvas.drawRect(camp, Paint()..color = SiddimColors.sand.withOpacity(0.95));

    // Camp line — crossing it costs a courage heart.
    final Paint line = Paint()
      ..color = SiddimColors.courage.withOpacity(0.55)
      ..strokeWidth = 2;
    const double dash = 10;
    for (double x = 0; x < size.width; x += dash * 2) {
      canvas.drawLine(
        Offset(x, size.height * campLine),
        Offset(math.min(x + dash, size.width), size.height * campLine),
        line,
      );
    }

    // Tents in the camp.
    final Paint tent = Paint()..color = SiddimColors.ridge.withOpacity(0.75);
    for (final double tx in <double>[0.14, 0.86]) {
      final double cx = size.width * tx;
      final double by = size.height * (campLine + 0.06);
      final Path path = Path()
        ..moveTo(cx, by - size.height * 0.055)
        ..lineTo(cx - size.width * 0.055, by)
        ..lineTo(cx + size.width * 0.055, by)
        ..close();
      canvas.drawPath(path, tent);
    }
  }

  void _paintSoldier(Canvas canvas, Size size, _Soldier soldier) {
    final double shortSide = math.min(size.width, size.height);
    final double r = hitRadius * shortSide * (soldier.isKing ? 1.0 : 1.25);
    // A near miss knocks the soldier back a step.
    final Offset c = Offset(
      soldier.x * size.width,
      (soldier.y - soldier.flinch * 0.012) * size.height,
    );
    final double alpha = soldier.opacity;
    if (alpha <= 0) return;

    final Color base = soldier.isKing ? SiddimColors.king : SiddimColors.soldier;
    final Color body = Color.lerp(base, Colors.white, soldier.flash * 0.7)!
        .withOpacity(alpha);

    // Soft halo so small targets stay findable against the dusk sky.
    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()..color = base.withOpacity(0.18 * alpha),
    );

    // Shield.
    canvas.drawCircle(
      c + Offset(0, r * 0.15),
      r * 0.62,
      Paint()..color = SiddimColors.soldierShield.withOpacity(0.9 * alpha),
    );
    canvas.drawCircle(
      c + Offset(0, r * 0.15),
      r * 0.62,
      Paint()
        ..color = body
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );

    // Body + helmet.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, r * 0.2),
          width: r * 0.7,
          height: r * 1.0,
        ),
        Radius.circular(r * 0.22),
      ),
      Paint()..color = body,
    );
    canvas.drawCircle(c - Offset(0, r * 0.55), r * 0.32, Paint()..color = body);

    if (soldier.isKing) {
      _paintCrown(canvas, c - Offset(0, r * 0.95), r * 0.5, alpha);
      _paintShieldMeter(canvas, c, r, soldier.hitsLeft, alpha);
    }
  }

  void _paintCrown(Canvas canvas, Offset center, double w, double alpha) {
    final Paint gold = Paint()
      ..color = SiddimColors.kingCrown.withOpacity(alpha);
    final Path crown = Path()
      ..moveTo(center.dx - w * 0.6, center.dy + w * 0.35)
      ..lineTo(center.dx - w * 0.6, center.dy - w * 0.35)
      ..lineTo(center.dx - w * 0.2, center.dy + w * 0.02)
      ..lineTo(center.dx, center.dy - w * 0.45)
      ..lineTo(center.dx + w * 0.2, center.dy + w * 0.02)
      ..lineTo(center.dx + w * 0.6, center.dy - w * 0.35)
      ..lineTo(center.dx + w * 0.6, center.dy + w * 0.35)
      ..close();
    canvas.drawPath(crown, gold);
  }

  /// The king's shield reads as three unmistakable states rather than a bar of
  /// ticks — a child should know at a glance how close the climax is.
  ///
  /// 3 hits left: whole and gold. 2: cracked silver. 1: broken, pieces adrift.
  void _paintShieldMeter(
      Canvas canvas, Offset center, double r, int hitsLeft, double alpha) {
    if (hitsLeft <= 0) return;

    final double radius = r * 1.4;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final (Color tint, double width, double opacity) = switch (hitsLeft) {
      >= 3 => (SiddimColors.kingCrown, r * 0.16, 0.95),
      2 => (const Color(0xFFD7DDE4), r * 0.13, 0.85),
      _ => (const Color(0xFF9AA5B1), r * 0.10, 0.65),
    };

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = tint.withOpacity(opacity * alpha);

    if (hitsLeft >= 3) {
      // Whole: an unbroken gold ring with a soft aura.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.4
          ..color = tint.withOpacity(0.22 * alpha),
      );
      canvas.drawCircle(center, radius, ring);
      return;
    }

    if (hitsLeft == 2) {
      // Cracked: still a full circle, but split by fissures.
      canvas.drawCircle(center, radius, ring);
      final Paint crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.55
        ..color = const Color(0xFF37474F).withOpacity(0.75 * alpha);
      for (final double a in <double>[-0.9, 0.4, 2.3]) {
        final Offset outer =
            center + Offset(math.cos(a), math.sin(a)) * radius;
        final Offset inner =
            center + Offset(math.cos(a + 0.35), math.sin(a + 0.35)) * radius * 0.45;
        canvas.drawLine(outer, inner, crack);
      }
      return;
    }

    // Broken: only fragments remain, drifting outward off the rim.
    const List<(double, double)> shards = <(double, double)>[
      (-math.pi / 2, 0.7),
      (0.35, 0.5),
      (2.5, 0.6),
    ];
    for (final (double start, double sweep) in shards) {
      canvas.drawArc(rect, start, sweep, false, ring);
    }
    final Paint fragment = Paint()..color = tint.withOpacity(0.7 * alpha);
    for (final double a in <double>[1.5, 3.4, 5.1]) {
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * radius * 1.25,
        r * 0.09,
        fragment,
      );
    }
  }

  void _paintArrow(Canvas canvas, Size size, _Arrow arrow) {
    final Offset tip = Offset(arrow.x * size.width, arrow.y * size.height);
    final Offset dir = Offset(
      arrow.vx * size.width,
      arrow.vy * size.height,
    );
    final Offset unit = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;
    final double len = math.min(size.width, size.height) * 0.075;
    final Offset tail = tip - unit * len;

    for (int i = 0; i < arrow.trail.length; i++) {
      final Offset p = Offset(
        arrow.trail[i].dx * size.width,
        arrow.trail[i].dy * size.height,
      );
      canvas.drawCircle(
        p,
        2.5 - i * 0.3,
        Paint()..color = Colors.white.withOpacity(0.28 - i * 0.04),
      );
    }

    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = SiddimColors.arrow
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Head.
    final Offset normal = Offset(-unit.dy, unit.dx);
    final Path head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
          (tip - unit * (len * 0.3) + normal * (len * 0.15)).dx,
          (tip - unit * (len * 0.3) + normal * (len * 0.15)).dy)
      ..lineTo(
          (tip - unit * (len * 0.3) - normal * (len * 0.15)).dx,
          (tip - unit * (len * 0.3) - normal * (len * 0.15)).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = SiddimColors.arrow);

    // Fletching.
    canvas.drawLine(
      tail,
      tail + normal * (len * 0.18) + unit * (len * 0.18),
      Paint()
        ..color = SiddimColors.arrowFletch
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      tail,
      tail - normal * (len * 0.18) + unit * (len * 0.18),
      Paint()
        ..color = SiddimColors.arrowFletch
        ..strokeWidth = 2.5,
    );
  }

  void _paintPuff(Canvas canvas, Size size, _Puff puff) {
    final Offset c = Offset(puff.x * size.width, puff.y * size.height);
    final double t = puff.progress;
    final double short = math.min(size.width, size.height);

    // A shot that just missed: a quick expanding ring plus the word, so the
    // child learns the shot was close rather than wondering what went wrong.
    if (puff.kind == _PuffKind.nearMiss) {
      canvas.drawCircle(
        c,
        short * (0.045 + t * 0.075),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFE082).withOpacity((1 - t) * 0.9),
      );
      _drawLabel(
        canvas,
        nearMissLabel,
        c - Offset(0, short * 0.085),
        const Color(0xFFFFE082).withOpacity((1 - t) * 0.95),
        short * 0.042,
      );
      return;
    }

    // An arrow off the king's shield: sparks thrown outward.
    if (puff.kind == _PuffKind.shieldSpark) {
      final Paint spark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = SiddimColors.kingCrown.withOpacity((1 - t) * 0.95);
      for (int i = 0; i < 8; i++) {
        final double a = i * math.pi / 4;
        final Offset dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          c + dir * short * (0.035 + t * 0.05),
          c + dir * short * (0.055 + t * 0.10),
          spark,
        );
      }
      canvas.drawCircle(
        c,
        short * (0.02 + t * 0.05),
        Paint()..color = Colors.white.withOpacity((1 - t) * 0.55),
      );
      return;
    }

    final double radius = short * (0.03 + t * 0.10);
    final Color color =
        puff.isKing ? SiddimColors.kingCrown : SiddimColors.soldierShield;

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withOpacity((1 - t) * 0.8),
    );

    // Retreat chevrons drifting back up the valley.
    final Paint chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity((1 - t) * 0.9);
    for (int i = 0; i < 2; i++) {
      final double dy = -radius * (0.6 + i * 0.5);
      final double w = radius * 0.35;
      canvas.drawLine(
          c + Offset(-w, dy + w * 0.6), c + Offset(0, dy - w * 0.2), chevron);
      canvas.drawLine(
          c + Offset(0, dy - w * 0.2), c + Offset(w, dy + w * 0.6), chevron);
    }
  }

  void _paintAbramAndBow(Canvas canvas, Size size) {
    final Offset anchor =
        Offset(bowAnchor.dx * size.width, bowAnchor.dy * size.height);
    final double scale = math.min(size.width, size.height) * 0.16;

    // Abram — robed figure at the camp.
    final Path robe = Path()
      ..moveTo(anchor.dx - scale * 0.30, anchor.dy + scale * 0.55)
      ..lineTo(anchor.dx - scale * 0.16, anchor.dy - scale * 0.20)
      ..lineTo(anchor.dx + scale * 0.16, anchor.dy - scale * 0.20)
      ..lineTo(anchor.dx + scale * 0.30, anchor.dy + scale * 0.55)
      ..close();
    canvas.drawPath(robe, Paint()..color = SiddimColors.abrahamRobe);
    canvas.drawCircle(
      Offset(anchor.dx, anchor.dy - scale * 0.34),
      scale * 0.17,
      Paint()..color = SiddimColors.abraham,
    );

    // Bow, rotated toward the aim point (or straight up when idle).
    final Offset target = aim ?? Offset(anchor.dx, anchor.dy - scale * 2);
    final Offset delta = target - anchor;
    final double angle =
        delta.distance == 0 ? -math.pi / 2 : math.atan2(delta.dy, delta.dx);
    final double pull = aim == null
        ? 0.2
        : (delta.distance / (size.height * 0.5)).clamp(0.25, 1.0);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy - scale * 0.15);
    canvas.rotate(angle + math.pi / 2);

    final double bowR = scale * 0.62;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: bowR),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      Paint()
        ..color = SiddimColors.bow
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.10
        ..strokeCap = StrokeCap.round,
    );

    final Offset limbTop = Offset(math.cos(-math.pi * 0.85) * bowR,
        math.sin(-math.pi * 0.85) * bowR);
    final Offset limbBottom = Offset(math.cos(-math.pi * 0.15) * bowR,
        math.sin(-math.pi * 0.15) * bowR);
    final Offset nock = Offset(bowR * 0.45 * pull, 0);
    final Path string = Path()
      ..moveTo(limbTop.dx, limbTop.dy)
      ..lineTo(nock.dx, nock.dy)
      ..lineTo(limbBottom.dx, limbBottom.dy);
    canvas.drawPath(
      string,
      Paint()
        ..color = SiddimColors.bowString
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();

    _paintAimGuide(canvas, size, anchor);
  }

  void _paintAimGuide(Canvas canvas, Size size, Offset anchor) {
    final Offset? target = aim;
    if (target == null) return;

    final Offset delta = target - anchor;
    if (delta.distance < 12) return;
    final Offset unit = delta / delta.distance;

    final Paint dot = Paint()..color = Colors.white.withOpacity(0.55);
    final double step = math.min(size.width, size.height) * 0.045;
    for (double d = step; d < delta.distance; d += step) {
      canvas.drawCircle(anchor + unit * d, 2.6, dot);
    }

    // Crosshair on the aim point.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.85);
    final double r = math.min(size.width, size.height) * 0.035;
    canvas.drawCircle(target, r, ring);
    canvas.drawLine(target - Offset(r * 1.5, 0), target - Offset(r * 0.6, 0), ring);
    canvas.drawLine(target + Offset(r * 0.6, 0), target + Offset(r * 1.5, 0), ring);
    canvas.drawLine(target - Offset(0, r * 1.5), target - Offset(0, r * 0.6), ring);
    canvas.drawLine(target + Offset(0, r * 0.6), target + Offset(0, r * 1.5), ring);
  }

  @override
  bool shouldRepaint(covariant _ArcheryPainter oldDelegate) => true;

  @override
  bool shouldRebuildSemantics(covariant _ArcheryPainter oldDelegate) => false;
}

// ------------------------------------------------------------------ hud + ui

/// The slice of game state the chrome around the field actually renders.
class _HudSnapshot {
  const _HudSnapshot(
    this.waveIndex,
    this.score,
    this.courage,
    this.remaining,
    this.phase,
  );

  final int waveIndex;
  final int score;
  final int courage;
  final int remaining;
  final _Phase phase;

  @override
  bool operator ==(Object other) =>
      other is _HudSnapshot &&
      other.waveIndex == waveIndex &&
      other.score == score &&
      other.courage == courage &&
      other.remaining == remaining &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(waveIndex, score, courage, remaining, phase);
}

class _ArcheryHud extends StatelessWidget {
  const _ArcheryHud({
    required this.roundLabel,
    required this.score,
    required this.courage,
    required this.maxCourage,
    required this.remaining,
  });

  final String roundLabel;
  final int score;
  final int courage;
  final int maxCourage;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      children: <Widget>[
        // The round label is the only variable-width item here, so it is the
        // one that gives way on a narrow screen.
        Flexible(
          child: _HudChip(
            icon: Icons.military_tech_rounded,
            label: roundLabel,
            color: SiddimColors.banner,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _HudChip(
          icon: Icons.star_rounded,
          label: '$score',
          color: KidsZoneColors.star,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Spacer(),
        Semantics(
          label: l10n.kidsZoneSiddimCourageLeft(courage),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(maxCourage, (int i) {
              return Icon(
                i < courage
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: SiddimColors.courage,
              );
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _HudChip(
          icon: Icons.shield_rounded,
          label: '$remaining',
          color: SiddimColors.soldier,
        ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsZoneText.nunito(size: 12, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseOverlay extends StatelessWidget {
  const _PhaseOverlay({
    required this.phase,
    required this.wave,
    required this.score,
    required this.accuracy,
    required this.card,
    required this.onRetry,
    required this.onFinish,
  });

  final _Phase phase;
  final ArcheryWave wave;
  final int score;
  final double accuracy;
  final ArcheryScorecard card;
  final VoidCallback onRetry;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final (String title, String body, IconData icon, Color color) =
        switch (phase) {
      // The march between rounds: story, not instructions.
      _Phase.interlude => (
          wave.title,
          wave.interlude,
          Icons.auto_stories_rounded,
          SiddimColors.kingCrown,
        ),
      _Phase.roundIntro => (
          wave.title,
          wave.cue,
          Icons.sports_martial_arts_rounded,
          SiddimColors.banner,
        ),
      _Phase.roundCleared => (
          l10n.kidsZoneSiddimRoundCleared,
          l10n.kidsZoneSiddimRoundStats(
            score,
            (accuracy * 100).round(),
          ),
          Icons.check_circle_rounded,
          const Color(0xFF66BB6A),
        ),
      _Phase.victory => (
          l10n.kidsZoneSiddimVictoryTitle,
          l10n.kidsZoneSiddimVictoryBody,
          Icons.emoji_events_rounded,
          SiddimColors.kingCrown,
        ),
      _Phase.breached => (
          l10n.kidsZoneSiddimBreached,
          l10n.kidsZoneSiddimBreachedBody,
          Icons.favorite_rounded,
          SiddimColors.courage,
        ),
      _Phase.playing => ('', '', Icons.circle, Colors.transparent),
    };

    return Container(
      color: Colors.black.withOpacity(0.45),
      child: KidsZoneFitOrScroll(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 64, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 22,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 15,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            // Why these stars, and what would earn another.
            if (phase == _Phase.breached || phase == _Phase.victory) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _ScoreBreakdown(card: card),
            ],
            if (phase == _Phase.breached) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.kidsZoneSiddimTryRoundAgain),
                style: FilledButton.styleFrom(
                  backgroundColor: SiddimColors.banner,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            if (phase == _Phase.victory) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.celebration_rounded),
                label: Text(l10n.kidsZoneGameFinish),
                style: FilledButton.styleFrom(
                  backgroundColor: SiddimColors.kingCrown,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          ],
          ),
      ),
    );
  }
}

/// The stop's result, and the rules the stars are judged by.
///
/// Kept as one value so the breakdown a child reads is literally the thing the
/// score was computed from.
class ArcheryScorecard {
  const ArcheryScorecard({
    required this.turnedBack,
    required this.totalSoldiers,
    required this.hits,
    required this.shots,
    required this.hearts,
    required this.maxHearts,
    required this.breaches,
    required this.score,
  });

  final int turnedBack;
  final int totalSoldiers;
  final int hits;
  final int shots;
  final int hearts;
  final int maxHearts;
  final int breaches;
  final int score;

  static const double accuracyGoal = 0.55;

  double get accuracy => shots == 0 ? 0 : hits / shots;

  int get accuracyPercent => (accuracy * 100).round();

  /// Star one is simply for finishing; these two are what lift it to three.
  bool get metNoBreach => breaches == 0;

  bool get metAccuracy => accuracy >= accuracyGoal;

  int get stars => metNoBreach && metAccuracy ? 3 : (breaches <= 1 ? 2 : 1);
}

/// Shows why the child earned the stars they did, and what would earn more.
class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.card});

  final ArcheryScorecard card;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _row(
            Icons.shield_rounded,
            l10n.kidsZoneSiddimStatTurnedBack,
            '${card.turnedBack}/${card.totalSoldiers}',
          ),
          _row(
            Icons.my_location_rounded,
            l10n.kidsZoneSiddimStatArrows,
            '${card.hits}/${card.shots}  (${card.accuracyPercent}%)',
          ),
          _row(
            Icons.favorite_rounded,
            l10n.kidsZoneSiddimStatHearts,
            '${card.hearts}/${card.maxHearts}',
          ),
          _row(
            Icons.star_rounded,
            l10n.kidsZoneSiddimStatPoints,
            '${card.score}',
          ),
          const Divider(color: Colors.white24, height: AppSpacing.lg),

          // The criteria themselves, so a replay has a target rather than a
          // vague sense of "do better".
          _goal(l10n.kidsZoneSiddimGoalNoBreach, card.metNoBreach),
          _goal(
            l10n.kidsZoneSiddimGoalAccuracy(
              (ArcheryScorecard.accuracyGoal * 100).round(),
            ),
            card.metAccuracy,
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: l10n.kidsZoneCompleteStars(card.stars),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(3, (int i) {
                return Icon(
                  i < card.stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: KidsZoneColors.star,
                  size: 30,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: KidsZoneText.nunito(
                size: 13,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            value,
            style: KidsZoneText.nunito(
              size: 13,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goal(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: met ? const Color(0xFF81C784) : Colors.white54,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: KidsZoneText.nunito(
                size: 12,
                weight: FontWeight.w700,
                color: met ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five fixed lanes across the valley, as focusable buttons.
///
/// This is the screen-reader path into the level: TalkBack consumes one-finger
/// swipes for its own navigation, so a gesture-based alternative would never
/// receive the input. Buttons can be focused and double-tapped.
class _LaneFireBar extends StatelessWidget {
  const _LaneFireBar({required this.enabled, required this.onFire});

  final bool enabled;
  final ValueChanged<double> onFire;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<(String, double, IconData)> lanes = <(String, double, IconData)>[
      (l10n.kidsZoneSiddimLaneFarLeft, 0.10, Icons.keyboard_double_arrow_left_rounded),
      (l10n.kidsZoneSiddimLaneLeft, 0.30, Icons.keyboard_arrow_left_rounded),
      (l10n.kidsZoneSiddimLaneAhead, 0.50, Icons.keyboard_arrow_up_rounded),
      (l10n.kidsZoneSiddimLaneRight, 0.70, Icons.keyboard_arrow_right_rounded),
      (l10n.kidsZoneSiddimLaneFarRight, 0.90, Icons.keyboard_double_arrow_right_rounded),
    ];

    return Row(
      children: <Widget>[
        for (final (String label, double x, IconData icon) in lanes)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: l10n.kidsZoneSiddimFireLane(label),
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: enabled ? () => onFire(x) : null,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: SiddimColors.banner.withOpacity(0.85),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Icon(icon, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
