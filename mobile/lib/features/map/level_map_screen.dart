import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/connectivity.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../models/session.dart';
import '../../services/game_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';
import '../kids_zone/play_mode_chooser.dart';
import 'level_detail_sheet.dart';
import 'level_map_progress.dart';
import 'parchment_codex_tokens.dart';
import 'parchment_codex_widgets.dart';

/// M-11 Level map — Parchment Codex direction 1a.
///
/// Lock/unlock state is server-driven; tile visuals derive from
/// [LevelMapProgress] so progress bar and chapter counts stay in sync.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  LevelMap? _map;
  bool _loading = true;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);

    final GameRepository game = context.read<GameRepository>();
    try {
      final LevelMap map = await game.levelMap();
      if (!mounted) return;
      setState(() {
        _map = map;
        _loading = false;
        _stale = false;
        _error = null;
      });
      context.read<SessionController>().applyProgress(
            highestLevelCompleted: map.highestLevelCompleted,
            levelsCompleted: map.levels.where((LevelSummary l) => l.completed).length,
          );
    } on ApiException catch (error) {
      if (!mounted) return;
      final LevelMap? cached = game.cachedLevelMap();
      setState(() {
        _loading = false;
        _map = _map ?? cached;
        _stale = _map != null;
        _error = _map == null
            ? (error.isOffline ? null : error.message)
            : null;
      });
    }
  }

  Future<void> _openLevel(LevelSummary level) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionController session = context.read<SessionController>();

    if (!session.canPlay) {
      _showConsentBlock();
      return;
    }

    if (level.locked) {
      final bool? unlocked = await Navigator.of(context).pushNamed<bool>(
        Routes.iapUnlock,
        arguments: IapArgs(
          trigger: IapTrigger.lockedLevelTap,
          returnToLevel: level.levelNumber,
        ),
      );
      if (unlocked == true && mounted) {
        await _load(showSpinner: false);
      }
      return;
    }

    if (!level.playable) {
      showAppSnack(context, l10n.levelDetailNotPlayable);
      return;
    }

    final LevelDetail? toPlay = await showLevelDetailSheet(
      context,
      levelNumber: level.levelNumber,
    );
    if (!mounted || toPlay == null) return;

    await Navigator.of(context).pushNamed(
      Routes.gameplay,
      arguments: GameplayArgs(level: toPlay),
    );
    if (mounted) await _load(showSpinner: false);
  }

  void _showConsentBlock() {
    final SessionUser? user = context.read<SessionController>().user;
    if (user == null) return;
    goToStep(context, OnboardingStep.parentalConsent);
  }

  Future<void> _unlockAll() async {
    await Navigator.of(context).pushNamed(
      Routes.iapUnlock,
      arguments: const IapArgs(trigger: IapTrigger.lockedLevelTap),
    );
    if (mounted) await _load(showSpinner: false);
  }

  int _pointsFromMap(LevelMap map) {
    return map.levels
        .where((LevelSummary level) => level.completed && level.bestScore != null)
        .fold<int>(0, (int sum, LevelSummary level) => sum + (level.bestScore ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionController session = context.watch<SessionController>();
    final bool offline = !context.watch<ConnectivityService>().isOnline;
    final LevelMap? map = _map;

    return ColoredBox(
      color: ParchmentColors.page,
      child: _buildBody(context, l10n, session, offline, map),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SessionController session,
    bool offline,
    LevelMap? map,
  ) {
    if (_loading && map == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ParchmentMapHeader(streak: 0, points: 0),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Layout.pageInset(context),
              AppSpacing.md,
              Layout.pageInset(context),
              0,
            ),
            child: PlayModeChooser(
              onKidsZone: () => Navigator.of(context).pushNamed(Routes.kidsZone),
            ),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: ParchmentColors.gold),
            ),
          ),
        ],
      );
    }

    if (map == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ParchmentMapHeader(streak: 0, points: 0),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Layout.pageInset(context),
              AppSpacing.md,
              Layout.pageInset(context),
              0,
            ),
            child: PlayModeChooser(
              onKidsZone: () => Navigator.of(context).pushNamed(Routes.kidsZone),
            ),
          ),
          Expanded(
            child: _error == null
                ? ErrorView.offline(context, onRetry: _load)
                : ErrorView(
                    title: l10n.errorGenericTitle,
                    message: _error!,
                    onRetry: _load,
                  ),
          ),
        ],
      );
    }

    final LevelMapProgress progress = LevelMapProgress.fromMap(map);
    final int lockedFrom = map.freeTierMaxLevel + 1;
    final int streak = session.user?.levelsCompletedCount ?? map.highestLevelCompleted;
    final int points = _pointsFromMap(map);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ParchmentMapHeader(streak: streak, points: points),
        Expanded(
          child: RefreshIndicator(
            color: ParchmentColors.gold,
            backgroundColor: ParchmentColors.cream,
            onRefresh: () => _load(showSpinner: false),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                Layout.pageInset(context),
                AppSpacing.md,
                Layout.pageInset(context),
                AppSpacing.xxl,
              ),
              children: <Widget>[
                if (offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: NoticeBanner(
                      message: l10n.offlineBadge,
                      tone: NoticeTone.warning,
                      icon: Icons.wifi_off_rounded,
                    ),
                  ),
                ParchmentJourneyCard(progress: progress),
                const SizedBox(height: AppSpacing.md),
                ParchmentUnlockRow(
                  hasUnlock: map.hasUnlock,
                  lockedFrom: lockedFrom,
                  totalLevels: map.totalLevels,
                  onUnlockAll: _unlockAll,
                ),
                if (!session.canPlay) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(
                    message: l10n.levelMapConsentPending,
                    tone: NoticeTone.warning,
                    icon: Icons.lock_person_rounded,
                    actionLabel: l10n.levelMapConsentPendingAction,
                    onAction: _showConsentBlock,
                  ),
                ],
                if (_stale) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(
                    message: l10n.levelMapSyncFailed,
                    tone: NoticeTone.warning,
                    icon: Icons.sync_problem_rounded,
                    actionLabel: l10n.actionRetry,
                    onAction: () => _load(showSpinner: false),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PlayModeChooser(
                  onKidsZone: () => Navigator.of(context).pushNamed(Routes.kidsZone),
                ),
                const SizedBox(height: AppSpacing.lg),
                ParchmentLevelGrid(
                  levels: map.levels,
                  progress: progress,
                  onLevelTap: _openLevel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
