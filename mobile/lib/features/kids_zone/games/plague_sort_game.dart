import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/state_views.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';
import '../widgets/egypt_plague_view.dart';
import '../widgets/pharaoh_resolve_meter.dart';

/// Moses Level 2 — put the ten plagues in order, and watch Egypt answer.
///
/// The mechanic is a sort, but the meaning is not: every correct placement
/// makes something happen to the Egypt behind the cards, and cracks Pharaoh's
/// resolve one more time. Without that the level would be the only one in Kids
/// Zone where the world does not respond to what the child does.
///
/// Nothing here punishes. A wrong card bounces gently back to the tray, costs
/// nothing, cracks nothing, and breaks no streak that mattered — there is no
/// timer, no score to lose, and the same ten cards stay available until they
/// are all placed.
class PlagueSortGame extends StatefulWidget {
  const PlagueSortGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
    this.debugAge,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  /// Testing seam for the age-defaulted round-3 preview, so a test does not
  /// have to stand up a whole signed-in session to check the default.
  @visibleForTesting
  final int? debugAge;

  @override
  State<PlagueSortGame> createState() => _PlagueSortGameState();
}

enum _Phase { roundIntro, playing, roundCleared, finished }

class _PlagueSortGameState extends State<PlagueSortGame> {
  /// How long an effect owns the backdrop before the next one may play.
  static const Duration _effectBeat = Duration(milliseconds: 1800);

  /// Each name in the round-3 preview.
  static const Duration _previewStep = Duration(milliseconds: 400);

  /// The tray's full height — a plague card plus its label, comfortably.
  static const double _trayHeight = 138;

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  late final TextToSpeechService _tts;

  _Phase _phase = _Phase.roundIntro;
  int _roundIndex = 0;

  /// Slot index (0-based within the round) → the card placed there.
  final Map<int, PlagueCard> _placed = <int, PlagueCard>{};
  List<PlagueCard> _tray = <PlagueCard>[];

  /// Cumulative across all three rounds — this is what the meter reads, and
  /// what the crown fall waits for.
  int _cracks = 0;
  int _wrongAttempts = 0;
  int _streak = 0;

  /// Slot the child just got wrong, for the gentle bounce-back highlight.
  int? _rejectedSlot;

  PlagueEffect? _playingEffect;
  final Set<PlagueEffect> _seenEffects = <PlagueEffect>{};
  bool _crownFallen = false;

  bool _previewOn = false;
  bool _previewRunning = false;
  int _previewIndex = -1;

  Timer? _effectTimer;
  Timer? _previewTimer;
  Timer? _rejectTimer;

  List<PlagueRound> get _rounds => widget.definition.plagueRounds;
  PlagueRound get _round => _rounds[_roundIndex];
  bool get _isFinalRound => _roundIndex == _rounds.length - 1;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TextToSpeechService>();
    _audio.startCreationAmbience(track: KidsZoneBgm.funky);
    _previewOn = _previewDefault;
    _dealRound();
  }

  @override
  void dispose() {
    _effectTimer?.cancel();
    _previewTimer?.cancel();
    _rejectTimer?.cancel();
    _tts.stop();
    _audio.stopAmbience();
    super.dispose();
  }

  /// The memory preview is a difficulty preference, not a rite of passage:
  /// on by default for older players, off for younger ones, and always
  /// toggleable either way so a confident younger child — or a parent — can
  /// turn it on.
  bool get _previewDefault {
    final int? age = widget.debugAge ?? _accountAge();
    if (age == null) return false;
    return age >= kPlaguePreviewDefaultAge;
  }

  /// The age collected at sign-up, when there is one.
  ///
  /// Tolerant of there being no session at all: the rest of Kids Zone is
  /// fully offline and needs no account, so a level that crashed without one
  /// would be the only thing in the zone that did. No age simply means the
  /// preview keeps its gentler default.
  int? _accountAge() {
    try {
      return context.read<SessionController>().user?.age;
    } on Object {
      return null;
    }
  }

  void _dealRound() {
    _placed.clear();
    // Shuffled from a seed fixed to the round, so a retry is the same puzzle
    // rather than a different one — a child re-learning an order should not
    // have the order re-arranged under them.
    _tray = _round.cards.toList()..shuffle(math.Random(_round.round * 7919));
    _phase = _Phase.roundIntro;
  }

  void _startRound() {
    if (_isFinalRound && _previewOn) {
      _runPreview();
      return;
    }
    setState(() => _phase = _Phase.playing);
  }

  /// Flashes the ten names across the timeline in the right order, then hands
  /// the shuffled tray over. Purely optional, and it changes nothing about
  /// scoring or the star thresholds.
  void _runPreview() {
    setState(() {
      _phase = _Phase.playing;
      _previewRunning = true;
      _previewIndex = 0;
    });
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(_previewStep, (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _previewIndex++;
        if (_previewIndex >= _round.orders.length) {
          _previewRunning = false;
          _previewIndex = -1;
          timer.cancel();
        }
      });
    });
  }

  // --------------------------------------------------------------- placing

  /// Where in the round's order this slot sits.
  int _orderForSlot(int slot) => _round.orders[slot];

  void _onDropped(int slot, PlagueCard card) {
    if (_previewRunning) return;

    if (card.order != _orderForSlot(slot)) {
      _registerWrong(slot);
      return;
    }
    _registerCorrect(slot, card);
  }

  /// A wrong card bounces back. It costs nothing: no heart, no score, no
  /// crack on the meter. The only thing it does is not extend the streak.
  void _registerWrong(int slot) {
    _rejectTimer?.cancel();
    setState(() {
      _wrongAttempts++;
      _streak = 0;
      _rejectedSlot = slot;
    });
    _audio.playConnect();
    _rejectTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _rejectedSlot = null);
    });
  }

  void _registerCorrect(int slot, PlagueCard card) {
    final bool lastOfAll =
        _isFinalRound && _cracks + 1 >= kPharaohResolveCracks;

    setState(() {
      _placed[slot] = card;
      _tray.remove(card);
      _streak++;
      // The meter counts correct placements across the whole level, capped,
      // so replaying an earlier round can never push it past ten.
      _cracks = math.min(kPharaohResolveCracks, _cracks + 1);
      _playingEffect = card.effect;
      _seenEffects.add(card.effect);
      // The crown falling and the meter shattering are the same event, read
      // from the same placement — they cannot land out of sync.
      if (lastOfAll) _crownFallen = true;
    });

    _audio.playCorrect();
    SemanticsService.announce(
      AppLocalizations.of(context).kidsZonePlaguePlaced(card.name),
      Directionality.of(context),
    );

    _effectTimer?.cancel();
    _effectTimer = Timer(_effectBeat, () {
      if (!mounted) return;
      setState(() => _playingEffect = null);
      if (_placed.length == _round.orders.length) _finishRound();
    });
  }

  void _finishRound() {
    _audio.playCelebrate();
    setState(
        () => _phase = _isFinalRound ? _Phase.finished : _Phase.roundCleared);
  }

  void _nextRound() {
    setState(() {
      _roundIndex++;
      _streak = 0;
      _dealRound();
    });
  }

  int get _stars => plagueSortStars(
        correct: _cracks,
        wrongAttempts: _wrongAttempts,
      );

  void _finish() {
    _audio.stopAmbience();
    widget.onComplete(_stars);
  }

  /// Moses, in the first person, on tap — never automatically, so it does not
  /// talk over a screen reader describing the card being dragged.
  void _speakCard(PlagueCard card) {
    unawaited(
      _tts
          .speak(plagueNarration(AppLocalizations.of(context), card),
              voice: TtsVoice.narrator)
          .catchError((Object _) {}),
    );
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (_rounds.isEmpty) {
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

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: _round.cue,
      readAloudText: _round.cue,
      pauseKidsZoneBgm: true,
      body: KidsZoneBoardLayout(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        gap: AppSpacing.sm,
        // Pharaoh's resolve meter is a single row of chips — it never needs a
        // third of the screen, and capping it keeps Egypt below at full size.
        headerMaxFraction: 0.22,
        header: Row(
          children: <Widget>[
            // The chip gives way first: the meter is the through-line for
            // the whole level and must never be the thing that clips.
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: MosesColors.water.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.kidsZonePlagueRoundLabel(
                      _round.round, _rounds.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KidsZoneText.nunito(
                      size: 11, weight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // The meter is a gauge, not something to be read line by line,
            // so at a large text scale it shrinks to fit rather than
            // widening past the screen. It still never clips.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: PharaohResolveMeter(
                  cracks: _cracks,
                  shattered: _cracks >= kPharaohResolveCracks,
                ),
              ),
            ),
          ],
        ),
        board: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints board) {
            // The tray is 138 tall wherever there is room for it. On a short
            // frame it takes at most two fifths instead, so Egypt — which is
            // the thing the child is watching — is never squeezed to nothing.
            final double trayHeight = math.min(_trayHeight, board.maxHeight * 0.4);
                return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Egypt, behind everything, reacting to each placement.
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: EgyptPlagueView(
                            effect: _playingEffect,
                            placed: _seenEffects,
                            crownFallen: _crownFallen,
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: _Timeline(
                              round: _round,
                              placed: _placed,
                              rejectedSlot: _rejectedSlot,
                              previewIndex: _previewRunning ? _previewIndex : -1,
                              enabled: _phase == _Phase.playing && !_previewRunning,
                              onDropped: _onDropped,
                            ),
                          ),
                        ),
                        if (_phase != _Phase.playing)
                          Positioned.fill(
                            child: _PlaguePhaseOverlay(
                              phase: _phase,
                              round: _round,
                              roundNumber: _round.round,
                              roundCount: _rounds.length,
                              stars: _stars,
                              showPreviewToggle: _isFinalRound,
                              previewOn: _previewOn,
                              onTogglePreview: (bool v) =>
                                  setState(() => _previewOn = v),
                              onStart: _startRound,
                              onNext: _nextRound,
                              onFinish: _finish,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: trayHeight,
                  child: _Tray(
                    cards: _tray,
                    enabled: _phase == _Phase.playing && !_previewRunning,
                    glowing: _streak >= kPlagueStreakGlow,
                    onSpeak: _speakCard,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
                );
          },
        ),
      ),
    );
  }
}

/// Moses's own line for a plague.
///
/// A switch on the typed effect rather than a string key looked up at runtime:
/// the generated localisations have no by-name accessor, and a switch is what
/// makes a missing line a compile error instead of a silent blank.
String plagueNarration(AppLocalizations l10n, PlagueCard card) =>
    switch (card.effect) {
      PlagueEffect.bloodRiver => l10n.kidsZonePlagueSayBlood,
      PlagueEffect.frogs => l10n.kidsZonePlagueSayFrogs,
      PlagueEffect.gnats => l10n.kidsZonePlagueSayGnats,
      PlagueEffect.flies => l10n.kidsZonePlagueSayFlies,
      PlagueEffect.livestock => l10n.kidsZonePlagueSayLivestock,
      PlagueEffect.boils => l10n.kidsZonePlagueSayBoils,
      PlagueEffect.hail => l10n.kidsZonePlagueSayHail,
      PlagueEffect.locusts => l10n.kidsZonePlagueSayLocusts,
      PlagueEffect.darkness => l10n.kidsZonePlagueSayDarkness,
      PlagueEffect.crownFall => l10n.kidsZonePlagueSayFirstborn,
    };

// -------------------------------------------------------------------- board

/// The numbered steps the cards land on.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.round,
    required this.placed,
    required this.rejectedSlot,
    required this.previewIndex,
    required this.enabled,
    required this.onDropped,
  });

  final PlagueRound round;
  final Map<int, PlagueCard> placed;
  final int? rejectedSlot;

  /// While the optional preview runs, the slot currently being revealed.
  final int previewIndex;
  final bool enabled;
  final void Function(int slot, PlagueCard card) onDropped;

  @override
  Widget build(BuildContext context) {
    final int count = round.orders.length;
    // Ten slots need two rows on a phone; five fit in one.
    final int columns = count > 5 ? 5 : count;

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.82,
      ),
      itemCount: count,
      itemBuilder: (BuildContext context, int slot) {
        return _Slot(
          step: slot + 1,
          order: round.orders[slot],
          card: placed[slot],
          rejected: rejectedSlot == slot,
          previewing: previewIndex == slot,
          enabled: enabled,
          onDropped: (PlagueCard c) => onDropped(slot, c),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.step,
    required this.order,
    required this.card,
    required this.rejected,
    required this.previewing,
    required this.enabled,
    required this.onDropped,
  });

  final int step;
  final int order;
  final PlagueCard? card;
  final bool rejected;
  final bool previewing;
  final bool enabled;
  final ValueChanged<PlagueCard> onDropped;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PlagueCard? filled = card;

    return DragTarget<PlagueCard>(
      onWillAcceptWithDetails: (_) => enabled && filled == null,
      onAcceptWithDetails: (DragTargetDetails<PlagueCard> d) =>
          onDropped(d.data),
      builder: (BuildContext context, List<PlagueCard?> hovering, __) {
        final bool hot = hovering.isNotEmpty && filled == null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: filled != null
                ? Colors.white.withOpacity(0.92)
                : Colors.black.withOpacity(hot ? 0.34 : 0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              // Rejected is amber, never red: a wrong card is a nudge, not a
              // failure, and it costs the child nothing.
              color: rejected
                  ? MosesColors.blessing
                  : previewing
                      ? MosesColors.blessing
                      : (hot ? MosesColors.reedLight : Colors.white38),
              width: rejected || hot || previewing ? 2.2 : 1,
            ),
          ),
          child: Center(
            child: filled != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(filled.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          filled.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: KidsZoneText.nunito(
                              size: 9, weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  )
                : previewing
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          kMosesPlagues
                              .firstWhere((PlagueCard c) => c.order == order)
                              .name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: KidsZoneText.nunito(
                            size: 9,
                            weight: FontWeight.w800,
                            color: MosesColors.blessing,
                          ),
                        ),
                      )
                    : Text(
                        l10n.kidsZonePlagueStep(step),
                        style: KidsZoneText.nunito(
                          size: 12,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- tray

class _Tray extends StatelessWidget {
  const _Tray({
    required this.cards,
    required this.enabled,
    required this.glowing,
    required this.onSpeak,
  });

  final List<PlagueCard> cards;
  final bool enabled;

  /// Three correct in a row. Cosmetic only — there is nothing to lose by
  /// breaking it, and breaking it takes nothing away.
  final bool glowing;
  final ValueChanged<PlagueCard> onSpeak;

  @override
  Widget build(BuildContext context) {
    // A `Wrap`, deliberately not a horizontally scrolling list. Every card is
    // a `Draggable`, so in a scrolling tray a sideways drag is claimed by the
    // card under the finger and the list never moves — which would leave the
    // later cards of a ten-card round unreachable. Fitting them all on screen
    // removes the gesture conflict instead of trying to arbitrate it.
    return Wrap(
      key: const ValueKey<String>('plague-tray'),
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final PlagueCard card in cards)
          _PlagueCardTile(
            card: card,
            enabled: enabled,
            glowing: glowing,
            onSpeak: () => onSpeak(card),
          ),
      ],
    );
  }
}

class _PlagueCardTile extends StatelessWidget {
  const _PlagueCardTile({
    required this.card,
    required this.enabled,
    required this.glowing,
    required this.onSpeak,
  });

  final PlagueCard card;
  final bool enabled;
  final bool glowing;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget face = _face(context, dragging: false);

    if (!enabled) return Opacity(opacity: 0.5, child: face);

    return Draggable<PlagueCard>(
      data: card,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.translate(
          offset: const Offset(-29, -34),
          child: _face(context, dragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: face),
      child: Semantics(
        label: l10n.kidsZonePlagueCardSemantics(card.name),
        child: face,
      ),
    );
  }

  Widget _face(BuildContext context, {required bool dragging}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glowing ? MosesColors.blessing : Colors.black12,
          width: glowing ? 2.2 : 1,
        ),
        boxShadow: <BoxShadow>[
          if (glowing)
            BoxShadow(
              color: MosesColors.blessing.withOpacity(dragging ? 0.75 : 0.5),
              blurRadius: dragging ? 18 : 10,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: dragging ? 12 : 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(card.emoji, style: const TextStyle(fontSize: 18)),
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KidsZoneText.nunito(size: 8, weight: FontWeight.w800),
          ),
          // Its own tap target, inside the draggable card. A tap here plays
          // Moses's line and does not pick the card up; a drag from anywhere
          // on the card does not play the line. That separation is what lets
          // a child who is not yet a confident reader hear what a card *is*
          // before deciding where it goes.
          Semantics(
            button: true,
            label: l10n.kidsZonePlagueHearSemantics(card.name),
            child: ExcludeSemantics(
              child: InkResponse(
                onTap: dragging ? null : onSpeak,
                radius: 18,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.volume_up_rounded,
                      size: 15, color: MosesColors.water),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- overlays

class _PlaguePhaseOverlay extends StatelessWidget {
  const _PlaguePhaseOverlay({
    required this.phase,
    required this.round,
    required this.roundNumber,
    required this.roundCount,
    required this.stars,
    required this.showPreviewToggle,
    required this.previewOn,
    required this.onTogglePreview,
    required this.onStart,
    required this.onNext,
    required this.onFinish,
  });

  final _Phase phase;
  final PlagueRound round;
  final int roundNumber;
  final int roundCount;
  final int stars;
  final bool showPreviewToggle;
  final bool previewOn;
  final ValueChanged<bool> onTogglePreview;
  final VoidCallback onStart;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final (String title, String body, String action, VoidCallback press) =
        switch (phase) {
      _Phase.roundIntro => (
          round.title,
          round.cue,
          l10n.kidsZonePlagueStart,
          onStart
        ),
      _Phase.roundCleared => (
          l10n.kidsZonePlagueRoundDone,
          l10n.kidsZonePlagueRoundDoneBody(roundNumber, roundCount),
          l10n.kidsZonePlagueNextRound,
          onNext,
        ),
      _Phase.finished => (
          l10n.kidsZonePlagueDoneTitle,
          l10n.kidsZonePlagueDoneBody,
          l10n.kidsZonePlagueCollectStars,
          onFinish,
        ),
      _Phase.playing => ('', '', '', onStart),
    };

    return Container(
      color: Colors.black.withOpacity(0.62),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
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
                    size: 32,
                    color: KidsZoneColors.star,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                  size: 20, weight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                  size: 13, weight: FontWeight.w600, color: Colors.white70),
            ),
            if (phase == _Phase.roundIntro && showPreviewToggle) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              // Offered, never imposed: an extra memory layer for a child who
              // wants one, and invisible to a child who does not. It changes
              // nothing about the stars.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Switch(
                    value: previewOn,
                    onChanged: onTogglePreview,
                    activeColor: MosesColors.blessing,
                  ),
                  Flexible(
                    child: Text(
                      l10n.kidsZonePlaguePreviewToggle,
                      style: KidsZoneText.nunito(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
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
        ),
      ),
    );
  }
}
