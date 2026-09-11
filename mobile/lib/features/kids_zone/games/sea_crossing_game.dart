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
import '../widgets/parted_sea_view.dart';

/// Moses Level 3 — Exodus 14, in four phases.
///
/// Phases 1 and 2 are the crossing and are scored. Phase 3, *Turn back the
/// army*, and phase 4, the celebration, are not: they are beats the child
/// enacts and is rewarded with, and scoring them would turn "watch the story
/// happen" into "perform the story correctly".
///
/// **On phase 3's ending.** The account ends with the sea returning over
/// Pharaoh's army, and this level now shows that — an explicit product
/// decision, taken knowing it departs from the approach used for the tenth
/// plague (a crown falls, not a person) and the Siddim archery rounds
/// (soldiers turn back, never harmed).
///
/// It is drawn at the register of a children's Bible illustration and held
/// there: distant silhouettes only, no faces, no figures, nobody shown
/// struggling. The chariots tip, slide under, and the water closes over the
/// place they were. If this ever grows more graphic than that, it has gone
/// past what was agreed.
class SeaCrossingGame extends StatefulWidget {
  const SeaCrossingGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  @override
  State<SeaCrossingGame> createState() => _SeaCrossingGameState();
}

class _SeaCrossingGameState extends State<SeaCrossingGame>
    with SingleTickerProviderStateMixin {
  /// How close to a beat a tap counts. Generous, and more generous still for
  /// phase 3's deliberate hand beats.
  static const double _hitWindow = 0.55;
  static const double _handHitWindow = 0.9;

  static const double _phaseIntroSeconds = 2.4;

  late final Ticker _ticker;
  late final TextToSpeechService _tts;
  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;
  double _clock = 0;
  double _phaseTime = 0;
  double _introTimer = _phaseIntroSeconds;

  int _phaseIndex = 0;
  bool _intro = true;
  bool _finished = false;

  /// Beats already resolved this phase, by index.
  final Set<int> _hitBeats = <int>{};
  final Set<int> _missedBeats = <int>{};

  /// Where each beat of the current phase sits on screen, as fractions.
  ///
  /// Scattered rather than centred: a target that is always in the same place
  /// only tests timing, and the child stops looking at the scene. Placed from
  /// a seed fixed to the phase, so a retry is the same run rather than a
  /// different one — the child is practising a pattern, not rolling dice.
  List<Offset> _beatSpots = <Offset>[];

  /// Scored hits, from phases 1 and 2 only.
  int _scoredHits = 0;

  /// Phase 3's own clock.
  final SeaClosingSequence _army = SeaClosingSequence();

  /// A decaying blush after a tap that landed nowhere near the target.
  double _stray = 0;

  double _separation = 0;
  double _crossing = 0;
  double _arrived = 0;
  double _flash = 0;

  List<SeaPhase> get _phases => widget.definition.seaPhases;
  SeaPhase get _phase => _phases[_phaseIndex];
  bool get _isArmyPhase => _phase.stage == SeaStage.closing;
  bool get _isLast => _phaseIndex >= _phases.length - 1;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TextToSpeechService>();
    _audio.startCreationAmbience(track: KidsZoneBgm.thrilling);
    _ticker = createTicker(_onTick)..start();
    _layOutBeats();
    _speak(_phase.narration);
    // The sea should fill the device: this is the one level whose whole point
    // is the scale of what is happening.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Scatters this phase's targets across the play area.
  void _layOutBeats() {
    final math.Random rng = math.Random(_phase.id.hashCode);
    _beatSpots = <Offset>[
      for (int i = 0; i < _phase.beats.length; i++)
        Offset(
          // Kept off the very edges so a target is never half under the HUD
          // or the notch, and never so far out that it cannot be reached
          // one-handed.
          0.18 + rng.nextDouble() * 0.64,
          0.24 + rng.nextDouble() * 0.56,
        ),
    ];
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

  void _speak(String text) {
    if (text.isEmpty) return;
    unawaited(
        _tts.speak(text, voice: TtsVoice.narrator).catchError((Object _) {}));
  }

  // ------------------------------------------------------------------ clock

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0 || _finished) return;

    _clock += dt;
    if (_flash > 0) _flash = math.max(0, _flash - dt / 0.4);
    if (_stray > 0) _stray = math.max(0, _stray - dt / 0.35);

    if (_intro) {
      _introTimer -= dt;
      if (_introTimer <= 0) setState(() => _intro = false);
      if (mounted) _frame.value++;
      return;
    }

    _phaseTime += dt;
    _advancePhase(dt);
    _expireBeats();

    if (mounted) _frame.value++;
  }

  void _advancePhase(double dt) {
    switch (_phase.stage) {
      case SeaStage.parting:
        // The walls rise with the beats that have landed, so the sea parting
        // is visibly the child's doing.
        _separation = (_hitBeats.length / _phase.beats.length).clamp(0.0, 1.0);
        if (_phaseTime >= _phase.durationSec) {
          _separation = 1;
          _nextPhase();
        }
      case SeaStage.parted:
        _separation = 1;
        _crossing = (_hitBeats.length / _phase.beats.length).clamp(0.0, 1.0);
        _arrived = _crossing;
        if (_phaseTime >= _phase.durationSec) {
          _crossing = 1;
          _arrived = 1;
          _nextPhase();
        }
      case SeaStage.closing:
        // Everyone is across before the chariots are ever on screen — the
        // pursuit and the people are never on the same ground.
        _arrived = 1;
        _crossing = 1;
        _army.tick(dt);
        _separation = 1 - _army.seaClose;
        if (_army.finished) _nextPhase();
      case SeaStage.calm:
        _separation = 0;
        if (_phaseTime >= _phase.durationSec) _finish();
      case SeaStage.closed:
        break;
    }
  }

  /// A beat the child never answered. Costs nothing anywhere — in the scored
  /// phases it simply does not add a hit, and in phase 3 it only means the
  /// army takes a little longer to turn.
  void _expireBeats() {
    for (int i = 0; i < _phase.beats.length; i++) {
      if (_hitBeats.contains(i) || _missedBeats.contains(i)) continue;
      if (_phaseTime > _phase.beats[i].time + _window) _missedBeats.add(i);
    }
  }

  double get _window => _isArmyPhase ? _handHitWindow : _hitWindow;

  // ------------------------------------------------------------------- taps

  /// A tap has to land *on* the target, not merely at the right moment.
  ///
  /// The timing window alone made this a metronome the child could answer
  /// without looking. Requiring the finger to find a target that moves around
  /// the frame is what makes it a game of attention.
  void _onTapAt(Offset local, Size area) {
    if (_intro || _finished) return;

    final ({int index, double closeness})? live = _liveBeat;
    if (live == null) return;

    final Offset spot = _spotFor(live.index, area);
    final double radius = _radiusFor(_phase.beats[live.index].kind);
    if ((local - spot).distance > radius) {
      // A miss in space, not in time. Costs nothing — it simply does not
      // claim the beat, and the beat stays live until its window closes.
      setState(() => _stray = 1);
      return;
    }

    setState(() {
      _hitBeats.add(live.index);
      _flash = 1;
      if (_phase.isScored) _scoredHits++;
      if (_isArmyPhase) _army.registerHit();
    });
    _audio.playCorrect();
  }

  Offset _spotFor(int index, Size area) {
    final Offset f =
        index < _beatSpots.length ? _beatSpots[index] : const Offset(0.5, 0.5);
    return Offset(f.dx * area.width, f.dy * area.height);
  }

  /// Generous, and more generous still for phase 3's deliberate hand beats.
  double _radiusFor(SeaBeatKind kind) => kind == SeaBeatKind.hand ? 78 : 58;

  // ------------------------------------------------------------------ flow

  void _nextPhase() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _phaseIndex++;
      _phaseTime = 0;
      _intro = true;
      _introTimer = _phaseIntroSeconds;
      _hitBeats.clear();
      _missedBeats.clear();
    });
    _layOutBeats();
    if (_isArmyPhase) {
      // The track's climax under the phase that needs it.
      _audio.playClimax();
    }
    _speak(_phase.narration);
    SemanticsService.announce(_phase.title, Directionality.of(context));
  }

  int get _stars => seaCrossingStars(hits: _scoredHits);

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    _audio.playCelebrate();
    _audio.stopAmbience();
    widget.onComplete(_stars);
  }

  // ------------------------------------------------------------------- view

  /// The beat the child should be answering right now, if any.
  ({int index, double closeness})? get _liveBeat {
    for (int i = 0; i < _phase.beats.length; i++) {
      if (_hitBeats.contains(i) || _missedBeats.contains(i)) continue;
      final double gap = (_phase.beats[i].time - _phaseTime).abs();
      if (gap <= _window) {
        return (index: i, closeness: 1 - gap / _window);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (_phases.isEmpty) {
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

    // Full-bleed: no app bar, no instruction card. The HUD and the exit
    // button float over the sea rather than shrinking it into a box.
    return Scaffold(
      backgroundColor: const Color(0xFF120C22),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final Size area = Size(c.maxWidth, c.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (TapDownDetails d) =>
                      _onTapAt(d.localPosition, area),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _frame,
                          builder: (BuildContext context, _, __) {
                            return PartedSeaView(
                              separation: _separation,
                              phase: _clock,
                              crossing: _crossing,
                              arrived: _arrived,
                              chariotAdvance:
                                  _isArmyPhase ? _army.chariotAdvance : -1,
                              wheelWobble: _army.wheelWobble,
                              sink: _isArmyPhase ? _army.sink : 0,
                              mosesRaised: _mosesRaised,
                              celebrating: _phase.stage == SeaStage.calm,
                            );
                          },
                        ),
                      ),
                      // The target, wherever this beat put it.
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _frame,
                          builder: (BuildContext context, _, __) {
                            final ({int index, double closeness})? beat =
                                _liveBeat;
                            if (beat == null || _intro) {
                              return const SizedBox.expand();
                            }
                            final Offset spot = _spotFor(beat.index, area);
                            final SeaBeatKind kind =
                                _phase.beats[beat.index].kind;
                            final double r = _radiusFor(kind);
                            return Stack(
                              children: <Widget>[
                                Positioned(
                                  left: spot.dx - r,
                                  top: spot.dy - r,
                                  width: r * 2,
                                  height: r * 2,
                                  child: _BeatTarget(
                                    key: const ValueKey<String>('sea-target'),
                                    kind: kind,
                                    closeness: beat.closeness,
                                    flash: _flash,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                    children: <Widget>[
                      _SeaExitButton(
                          onPressed: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SeaHud(
                          phaseLabel: l10n.kidsZoneSeaPhaseLabel(
                              _phaseIndex + 1, _phases.length),
                          title: _phase.title,
                          scored: _phase.isScored,
                          hits: _scoredHits,
                          total: kSeaScoredBeats,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // A brief blush where a tap landed nowhere near the target — enough
          // to say "not there", and nothing more. It costs nothing.
          if (_stray > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(0.05 * _stray),
                ),
              ),
            ),
          if (_intro)
            Positioned.fill(
              child: _PhaseCard(title: _phase.title, cue: _phase.cue),
            ),
        ],
      ),
    );
  }

  /// How high Moses is holding the staff: up while he is parting the sea and
  /// again while he is closing it, down while the people walk.
  double get _mosesRaised => switch (_phase.stage) {
        SeaStage.parting => _separation,
        SeaStage.closing => (_army.seaClose * 0.4 + 0.6),
        SeaStage.parted => 0.15,
        SeaStage.calm || SeaStage.closed => 0,
      };
}

/// A small translucent circle, top-left, clear of the sea.
class _SeaExitButton extends StatelessWidget {
  const _SeaExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: Material(
        color: Colors.black.withOpacity(0.34),
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

// --------------------------------------------------------------------- HUD

class _SeaHud extends StatelessWidget {
  const _SeaHud({
    required this.phaseLabel,
    required this.title,
    required this.scored,
    required this.hits,
    required this.total,
  });

  final String phaseLabel;
  final String title;
  final bool scored;
  final int hits;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        // Flexible, because at a large text scale the phase chip on its own was
        // wider than the strip it shares with the title.
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: MosesColors.water.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              phaseLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsZoneText.nunito(size: 11, weight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KidsZoneText.nunito(size: 12, weight: FontWeight.w800),
          ),
        ),
        const Spacer(),
        // Only shown while it means something. During the unscored phases
        // there is no counter ticking, because nothing is being counted.
        if (scored)
          Semantics(
            label: l10n.kidsZoneSeaBeatsSemantics(hits, total),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded,
                      size: 15, color: MosesColors.blessing),
                  const SizedBox(width: 3),
                  Text('$hits',
                      style: KidsZoneText.nunito(
                          size: 12, weight: FontWeight.w800)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The thing to tap.
class _BeatTarget extends StatelessWidget {
  const _BeatTarget({
    super.key,
    required this.kind,
    required this.closeness,
    required this.flash,
  });

  final SeaBeatKind kind;

  /// 1 exactly on the beat, 0 at the edge of the window.
  final double closeness;
  final double flash;

  @override
  Widget build(BuildContext context) {
    // The hand is bigger and calmer than the step circle — this is Moses
    // stretching out his hand again, not another tempo prompt.
    final bool hand = kind == SeaBeatKind.hand;
    final double size = (hand ? 108.0 : 72.0) * (0.85 + 0.15 * closeness);

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MosesColors.blessing.withOpacity(0.18 + 0.22 * closeness),
          border: Border.all(
            color: MosesColors.blessing.withOpacity(0.55 + 0.45 * closeness),
            width: hand ? 3.5 : 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color:
                  MosesColors.blessing.withOpacity(0.35 * (closeness + flash)),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          hand ? Icons.back_hand_rounded : Icons.circle_outlined,
          size: size * 0.42,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.title, required this.cue});

  final String title;
  final String cue;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
                size: 20, weight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            cue,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
                size: 13, weight: FontWeight.w600, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
