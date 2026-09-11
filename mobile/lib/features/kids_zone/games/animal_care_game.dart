import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../../core/local_store.dart';
import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../widgets/state_views.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Something an animal is waiting for, and how it is feeling about the wait.
///
/// Deliberately *not* a countdown. A draining timer says "you are running out
/// of time" and turns caretaking into a race — which is the opposite of the
/// Kids Zone rule that nothing punishes with a clock. A need is never lost and
/// never expires: the animal simply gets less happy while it waits, and cheers
/// up the moment it is cared for.
class _ActiveNeed {
  _ActiveNeed({required this.need, required this.spawnedAt});

  final ArkCareNeed need;
  final double spawnedAt;

  /// 1 = content, 0 = sad. Recovers instantly when the need is met.
  double happiness = 1;

  /// Set once when happiness bottoms out, so the points are docked only once.
  bool countedSad = false;

  bool get isSad => happiness <= 0;
}

enum _Phase { tutorial, roundIntro, playing, roundCleared, finished }

/// Level 3 — keep every animal aboard fed, watered, clean and comforted.
///
/// Animals ask for things; the child notices, picks the matching tool, and
/// helps. Nothing expires and nothing is failed — an unmet animal just grows
/// less happy, and cheers up as soon as it is cared for.
class AnimalCareGame extends StatefulWidget {
  const AnimalCareGame({
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
  State<AnimalCareGame> createState() => _AnimalCareGameState();
}

class _AnimalCareGameState extends State<AnimalCareGame>
    with SingleTickerProviderStateMixin {
  static const double _roundIntroSeconds = 2.4;

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  final math.Random _random = math.Random();

  /// Repaints the patience rings without rebuilding the whole screen.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  late final Ticker _ticker;

  final Map<String, _ActiveNeed> _needs = <String, _ActiveNeed>{};

  Duration _lastTick = Duration.zero;
  double _clock = 0;
  double _spawnTimer = 0;
  double _phaseTimer = _roundIntroSeconds;

  _Phase _phase = _Phase.tutorial;
  int _roundIndex = 0;
  int _tasksDone = 0;
  /// How many times an animal was left waiting long enough to look sad.
  int _sadSpells = 0;
  int _wrongTool = 0;
  int _score = 0;
  ArkCareNeed? _selectedTool;

  List<ArkCareRound> get _rounds => widget.definition.arkCareRounds;

  ArkCareRound get _round => _rounds[_roundIndex];

  bool get _isLastRound => _roundIndex >= _rounds.length - 1;

  /// How the animals are doing right now: content stalls count as fully happy,
  /// waiting ones contribute however they feel. This is the meter the child
  /// watches, and it recovers as soon as they help.
  double get _herdHappiness {
    final int stalls = _round.stalls.length;
    if (stalls == 0) return 1;
    double total = stalls.toDouble();
    for (final _ActiveNeed need in _needs.values) {
      total -= (1 - need.happiness);
    }
    return (total / stalls).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _audio.startCreationAmbience(track: KidsZoneBgm.thrilling);
    _ticker = createTicker(_onTick)..start();

    // The three-round escalation only works if the child already knows which
    // tool answers which icon, so the mapping is taught before round one — but
    // only the first time. After that it lives behind the help button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final LocalStore store = context.read<LocalStore>();
      if (store.isKidsZoneTutorialSeen(_tutorialId)) {
        setState(() => _phase = _Phase.roundIntro);
      }
    });
  }

  static const String _tutorialId = 'ark_animal_care';

  void _dismissTutorial() {
    context.read<LocalStore>().markKidsZoneTutorialSeen(_tutorialId);
    setState(() {
      _phase = _Phase.roundIntro;
      _phaseTimer = _roundIntroSeconds;
    });
  }

  void _showTutorial() => setState(() => _phase = _Phase.tutorial);

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _audio.stopAmbience();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    _clock += dt;

    switch (_phase) {
      // Held until the child says they are ready — never on a clock.
      case _Phase.tutorial:
        break;
      case _Phase.roundIntro:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) {
          setState(() {
            _phase = _Phase.playing;
            _spawnTimer = 0.8;
          });
          SemanticsService.announce(_round.cue, Directionality.of(context));
        }
      case _Phase.playing:
        _advancePlay(dt);
      case _Phase.roundCleared:
      case _Phase.finished:
        break;
    }

    if (mounted) _frame.value++;
  }

  void _advancePlay(double dt) {
    // Spawn new needs.
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && _needs.length < _round.stalls.length) {
      _spawnTimer = _round.spawnInterval;
      _spawnNeed();
    }

    // Waiting animals grow less happy — but they keep waiting. Nothing is ever
    // lost, so there is no moment of failure to recover from, only an animal
    // who could be happier.
    bool sadNow = false;
    for (final _ActiveNeed need in _needs.values) {
      if (need.happiness <= 0) continue;
      need.happiness =
          math.max(0, need.happiness - dt / _round.patienceSeconds);
      if (need.happiness <= 0 && !need.countedSad) {
        need.countedSad = true;
        _sadSpells += 1;
        _score = math.max(0, _score - 25);
        sadNow = true;
      }
    }
    if (sadNow) {
      _audio.playConnect();
      setState(() {});
    }
  }

  void _spawnNeed() {
    final List<ArkStall> free = _round.stalls
        .where((ArkStall s) => !_needs.containsKey(s.id))
        .toList(growable: false);
    if (free.isEmpty) return;

    final ArkStall stall = free[_random.nextInt(free.length)];
    final ArkCareNeed need =
        ArkCareNeed.values[_random.nextInt(ArkCareNeed.values.length)];

    setState(() {
      _needs[stall.id] = _ActiveNeed(need: need, spawnedAt: _clock);
    });
  }

  void _tapStall(ArkStall stall) {
    if (_phase != _Phase.playing) return;
    final AppLocalizations l10n = AppLocalizations.of(context);

    final _ActiveNeed? need = _needs[stall.id];
    if (need == null) return;

    final ArkCareNeed? tool = _selectedTool;
    if (tool == null) {
      showAppSnack(context, l10n.kidsZoneArkPickToolFirst);
      return;
    }

    if (tool != need.need) {
      _audio.playSparkle();
      setState(() => _wrongTool += 1);
      return;
    }

    _audio.playCorrect();
    setState(() {
      final _ActiveNeed served = _needs.remove(stall.id)!;
      _tasksDone += 1;
      // Cheering up a sad animal is worth the most — that is the whole job.
      _score += served.isSad ? 60 : 40;
    });
    SemanticsService.announce(
      l10n.kidsZoneArkCared(stall.animalLabel),
      Directionality.of(context),
    );

    if (_tasksDone >= _round.tasksToComplete) _clearRound();
  }

  void _clearRound() {
    _audio.playCelebrate();
    setState(() {
      _needs.clear();
      _phase = _isLastRound ? _Phase.finished : _Phase.roundCleared;
    });
  }

  void _nextRound() {
    setState(() {
      _roundIndex += 1;
      _tasksDone = 0;
      _needs.clear();
      _selectedTool = null;
      _phase = _Phase.roundIntro;
      _phaseTimer = _roundIntroSeconds;
    });
  }

  void _finish() {
    _ticker.stop();
    // Three stars needs a contented herd, nobody left to get sad, and the
    // right tool most of the time.
    final double herd = _herdHappiness;
    final int stars = herd >= 0.85 && _sadSpells == 0 && _wrongTool <= 2
        ? 3
        : (herd >= 0.6 ? 2 : 1);
    widget.onComplete(stars);
  }

  /// How happy the animal in this stall is feeling about its wait.
  double _needHappiness(String stallId) => _needs[stallId]?.happiness ?? 1;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: _round.cue,
      readAloudText: _round.cue,
      pauseKidsZoneBgm: true,
      body: Stack(
        children: <Widget>[
          Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CareHud(
              roundLabel:
                  l10n.kidsZoneArkRoundLabel(_round.round, _rounds.length),
              tasksLabel: l10n.kidsZoneArkTasks(
                _tasksDone,
                _round.tasksToComplete,
              ),
              happiness: _herdHappiness,
              onHelp: _showTutorial,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Stack(
                children: <Widget>[
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: _round.stalls.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ArkStall stall = _round.stalls[index];
                      return _StallCard(
                        stall: stall,
                        need: _needs[stall.id]?.need,
                        frame: _frame,
                        happiness: () => _needHappiness(stall.id),
                        onTap: () => _tapStall(stall),
                      );
                    },
                  ),
                  if (_phase != _Phase.playing &&
                      _phase != _Phase.tutorial)
                    _CarePhaseOverlay(
                      phase: _phase,
                      round: _round,
                      happiness: _herdHappiness,
                      onNext: _nextRound,
                      onFinish: _finish,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Toolbar(
              selected: _selectedTool,
              onSelect: (ArkCareNeed tool) =>
                  setState(() => _selectedTool = tool),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
          ),
          // Covers the toolbar as well as the stalls: the mapping is what is
          // being taught, so nothing should be tappable until it is read.
          if (_phase == _Phase.tutorial)
            Positioned.fill(child: _CareTutorial(onStart: _dismissTutorial)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ visuals

IconData careIcon(ArkCareNeed need) => switch (need) {
      ArkCareNeed.food => Icons.grass_rounded,
      ArkCareNeed.water => Icons.water_drop_rounded,
      ArkCareNeed.clean => Icons.cleaning_services_rounded,
      ArkCareNeed.comfort => Icons.favorite_rounded,
    };

Color careColor(ArkCareNeed need) => switch (need) {
      ArkCareNeed.food => ArkColors.straw,
      ArkCareNeed.water => ArkColors.water,
      ArkCareNeed.clean => ArkColors.leaf,
      ArkCareNeed.comfort => ArkColors.heart,
    };

String careLabel(AppLocalizations l10n, ArkCareNeed need) => switch (need) {
      ArkCareNeed.food => l10n.kidsZoneArkToolFood,
      ArkCareNeed.water => l10n.kidsZoneArkToolWater,
      ArkCareNeed.clean => l10n.kidsZoneArkToolClean,
      ArkCareNeed.comfort => l10n.kidsZoneArkToolComfort,
    };

class _StallCard extends StatelessWidget {
  const _StallCard({
    required this.stall,
    required this.need,
    required this.frame,
    required this.happiness,
    required this.onTap,
  });

  final ArkStall stall;
  final ArkCareNeed? need;
  final ValueNotifier<int> frame;
  final double Function() happiness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: need == null
          ? stall.animalLabel
          : '${stall.animalLabel}, ${careLabel(l10n, need!)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: need == null
                  ? ArkColors.timber.withOpacity(0.25)
                  : careColor(need!),
              width: need == null ? 1.5 : 3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ArkColors.timberDark.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          // The stall is a fixed cell in a grid, so its contents have to fit it
          // rather than the other way round: at a large text scale the animal
          // and its name together stood 29px taller than the cell.
          child: FittedBox(
            fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // The animal is a picture, not something to be read, so it
                    // keeps its drawn size while the name below it scales.
                    Text(
                      stall.emoji,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 42),
                    ),
                    if (need != null)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: AnimatedBuilder(
                          animation: frame,
                          builder: (BuildContext context, _) {
                            return _NeedBubble(
                              need: need!,
                              happiness: happiness(),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stall.animalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KidsZoneText.nunito(size: 13, weight: FontWeight.w800),
                ),
              ],
              ),
          ),
        ),
      ),
    );
  }
}

/// What an animal is asking for, and how it is feeling about the wait.
///
/// The ring reads as the animal's mood, not a countdown — it never runs out and
/// nothing is lost when it empties. A waiting animal simply looks less happy.
class _NeedBubble extends StatelessWidget {
  const _NeedBubble({required this.need, required this.happiness});

  final ArkCareNeed need;
  final double happiness;

  @override
  Widget build(BuildContext context) {
    final bool sad = happiness <= 0;

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: sad ? 1 : happiness,
            strokeWidth: 3,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(
              sad
                  ? ArkColors.heart.withOpacity(0.5)
                  : Color.lerp(
                      ArkColors.straw,
                      careColor(need),
                      happiness,
                    )!,
            ),
          ),
          Icon(
            careIcon(need),
            size: 16,
            color: sad ? ArkColors.heart : careColor(need),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.selected, required this.onSelect});

  final ArkCareNeed? selected;
  final ValueChanged<ArkCareNeed> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      children: <Widget>[
        for (final ArkCareNeed tool in ArkCareNeed.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                selected: selected == tool,
                label: careLabel(l10n, tool),
                child: GestureDetector(
                  onTap: () => onSelect(tool),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == tool
                          ? careColor(tool).withOpacity(0.9)
                          : careColor(tool).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: careColor(tool),
                        width: selected == tool ? 2.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          careIcon(tool),
                          size: 22,
                          color: selected == tool
                              ? Colors.white
                              : careColor(tool),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          careLabel(l10n, tool),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KidsZoneText.nunito(
                            size: 10,
                            weight: FontWeight.w800,
                            color: selected == tool
                                ? Colors.white
                                : KidsZoneColors.ink,
                          ),
                        ),
                      ],
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

class _CareHud extends StatelessWidget {
  const _CareHud({
    required this.roundLabel,
    required this.tasksLabel,
    required this.happiness,
    required this.onHelp,
  });

  final String roundLabel;
  final String tasksLabel;
  final double happiness;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      children: <Widget>[
        // Flexible for the same reason the task count is: at a large text scale
        // the chip's own label was wide enough to push the meter off the row.
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ArkColors.timber.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              roundLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsZoneText.nunito(size: 12, weight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // The round chip, task count, help button and happiness meter have to
        // share a narrow handset width, so the wordiest part gives way first.
        Flexible(
          child: Text(
            tasksLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KidsZoneText.nunito(size: 13, weight: FontWeight.w800),
          ),
        ),
        const Spacer(),
        // The mapping card is shown unprompted only once; after that a child who
        // forgets which tool is which can reopen it here instead of guessing.
        IconButton(
          onPressed: onHelp,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          tooltip: l10n.kidsZoneArkTutorialHelp,
          icon: const Icon(Icons.help_outline_rounded, size: 20),
        ),
        const SizedBox(width: 4),
        Semantics(
          label: l10n.kidsZoneArkHappiness((happiness * 100).round()),
          child: SizedBox(
            width: 70,
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.sentiment_very_satisfied_rounded,
                  size: 18,
                  color: ArkColors.leaf,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: happiness,
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        happiness >= 0.6
                            ? ArkColors.leaf
                            : (happiness >= 0.3
                                ? ArkColors.straw
                                : ArkColors.heart),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CarePhaseOverlay extends StatelessWidget {
  const _CarePhaseOverlay({
    required this.phase,
    required this.round,
    required this.happiness,
    required this.onNext,
    required this.onFinish,
  });

  final _Phase phase;
  final ArkCareRound round;
  final double happiness;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool finished = phase == _Phase.finished;

    final (String title, String body, IconData icon) = switch (phase) {
      // Never reached: _CareTutorial renders this phase instead.
      _Phase.tutorial => ('', '', Icons.school_rounded),
      _Phase.roundIntro => (
          round.title,
          round.cue,
          Icons.pets_rounded,
        ),
      _Phase.roundCleared => (
          l10n.kidsZoneArkRoundDone,
          l10n.kidsZoneArkHappiness((happiness * 100).round()),
          Icons.check_circle_rounded,
        ),
      _Phase.finished => (
          l10n.kidsZoneArkCareDoneTitle,
          l10n.kidsZoneArkCareDoneBody,
          Icons.volunteer_activism_rounded,
        ),
      _Phase.playing => ('', '', Icons.circle),
    };

    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 60, color: ArkColors.straw),
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
          if (phase == _Phase.roundCleared || finished) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: finished ? onFinish : onNext,
              icon: Icon(
                finished ? Icons.celebration_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(
                finished ? l10n.kidsZoneGameFinish : l10n.kidsZoneArkNextRound,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: finished ? ArkColors.leaf : ArkColors.timber,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Teaches the icon-to-tool mapping before the first round.
///
/// Without this the child meets a hungry animal and a row of unexplained tools,
/// and is penalised for guessing. Shown once, then reachable from the help
/// button whenever they want a reminder.
class _CareTutorial extends StatelessWidget {
  const _CareTutorial({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      color: Colors.black.withOpacity(0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.kidsZoneArkTutorialTitle,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 20,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.kidsZoneArkTutorialBody,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final ArkCareNeed need in ArkCareNeed.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                // Bubble, arrow and tool read as one phrase, so the row scales
                // as a unit rather than wrapping the arrow onto its own line.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // The bubble the animal shows...
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        careIcon(need),
                        size: 20,
                        color: careColor(need),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // ...and the tool that answers it.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: careColor(need).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        careLabel(l10n, need),
                        style: KidsZoneText.nunito(
                          size: 13,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.pets_rounded),
              label: Text(l10n.kidsZoneArkTutorialStart),
              style: FilledButton.styleFrom(
                backgroundColor: ArkColors.leaf,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
