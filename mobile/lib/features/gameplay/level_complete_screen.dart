import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/local_store.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../models/session.dart';
import '../../services/account_repository.dart';
import '../../services/ads_service.dart';
import '../../services/analytics_service.dart';
import '../../services/game_repository.dart';
import '../../services/notification_service.dart';
import '../../services/text_to_speech_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/celebration_animation.dart';
import '../../widgets/parchment_ui.dart';
import '../../widgets/state_views.dart';

/// M-14 Level complete (design-spec §1D, §22, §20).
class LevelCompleteScreen extends StatefulWidget {
  const LevelCompleteScreen({super.key, required this.args});

  final LevelCompleteArgs args;

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen> {
  bool _showNotifyPrompt = false;
  bool _notifyBusy = false;
  String? _notifyError;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  @override
  void dispose() {
    context.read<TextToSpeechService>().stop();
    super.dispose();
  }

  Future<void> _afterFirstFrame() async {
    if (!mounted) return;

    final NotificationService notifications = context.read<NotificationService>();
    if (!notifications.optedIn && !notifications.promptAlreadyShown) {
      await notifications.markPromptShown();
      if (!mounted) return;
      setState(() => _showNotifyPrompt = true);
    }

    final SessionUser? user = context.read<SessionController>().user;
    if (user == null) return;
    final AdsService ads = context.read<AdsService>();
    if (ads.shouldShowInterstitial(
      user: user,
      levelNumber: widget.args.levelNumber,
      serverAdEligible: widget.args.adEligible,
    )) {
      await ads.loadInterstitial();
    }
  }

  Future<void> _enableReminders() async {
    setState(() {
      _notifyBusy = true;
      _notifyError = null;
    });

    // Everything this method needs from the tree is resolved up front, before
    // the first await. The permission request opens an OS dialog, and looking
    // anything up afterwards is a lookup on a element that may already be
    // defunct — which throws rather than returning null.
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationService notifications = context.read<NotificationService>();
    final LocalStore store = context.read<LocalStore>();
    final AccountRepository account = context.read<AccountRepository>();
    final SessionController session = context.read<SessionController>();

    final bool granted = await notifications.requestPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _notifyBusy = false;
        _notifyError = l10n.levelCompleteNotifyDenied;
      });
      return;
    }

    await notifications.setOptIn(true);
    final int currentLevel = store.currentLevel;
    await notifications.rescheduleForActiveSession(
      currentLevel: currentLevel,
      reminder3dTitle: l10n.notification3dTitle,
      reminder3dBody: l10n.notification3dBody(currentLevel),
      reminder7dTitle: l10n.notification7dTitle,
      reminder7dBody: l10n.notification7dBody,
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDescription,
    );

    try {
      await account.updateNotificationsOptIn(true);
      // Not guarded on `mounted`: the opt-in really happened and the server has
      // accepted it, so the session should say so whether or not this screen
      // survived the round trip.
      session.applyNotificationsOptIn(true);
    } on ApiException {
      // Local schedule already set.
    }

    if (!mounted) return;
    setState(() {
      _notifyBusy = false;
      _showNotifyPrompt = false;
    });
  }

  Future<void> _declineReminders() async {
    await context.read<NotificationService>().setOptIn(false);
    if (!mounted) return;
    setState(() => _showNotifyPrompt = false);
  }

  Future<void> _continue({required bool toNextLevel}) async {
    if (_advancing) return;
    setState(() => _advancing = true);

    final LevelCompleteArgs args = widget.args;
    final SessionUser? user = context.read<SessionController>().user;
    final AdsService ads = context.read<AdsService>();

    final bool wantsAd = user != null &&
        ads.shouldShowInterstitial(
          user: user,
          levelNumber: args.levelNumber,
          serverAdEligible: args.adEligible,
        );

    final bool paywalled = toNextLevel && args.nextLevelLocked;

    if (wantsAd) {
      await Navigator.of(context).pushReplacementNamed(
        Routes.adBreak,
        arguments: AdBreakArgs(
          levelNumber: args.levelNumber,
          next: paywalled ? AdBreakDestination.iapPrompt : AdBreakDestination.levelMap,
        ),
      );
      return;
    }

    if (paywalled) {
      await Navigator.of(context).pushReplacementNamed(
        Routes.iapUnlock,
        arguments: const IapArgs(trigger: IapTrigger.levelFiveComplete),
      );
      return;
    }

    if (!mounted) return;

    if (toNextLevel && args.nextLevelNumber != null) {
      await _openNextLevel(args.nextLevelNumber!);
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _openNextLevel(int levelNumber) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final LevelDetail detail =
          await context.read<GameRepository>().levelDetail(levelNumber);
      if (!mounted) return;
      if (!detail.playable || detail.locked) {
        showAppSnack(context, l10n.levelDetailNotPlayable);
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        Routes.gameplay,
        arguments: GameplayArgs(level: detail),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _advancing = false);
      showAppSnack(context, error.isOffline ? l10n.errorOfflineBody : error.message);
    }
  }

  void _viewLeaderboard() {
    context.read<AnalyticsService>().track(
      'leaderboard_viewed',
      properties: <String, Object?>{
        'entry_source': 'post_level_complete',
        'user_rank': widget.args.userRank,
      },
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.home,
      (Route<dynamic> route) => false,
      arguments: const HomeArgs(tab: HomeTab.leaderboard),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LevelCompleteArgs args = widget.args;

    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: ParchmentColors.page,
        child: Scaffold(
          backgroundColor: ParchmentColors.page,
          body: SafeArea(
            child: SingleChildScrollView(
              child: ContentColumn(
                maxWidth: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    const Center(child: CelebrationAnimation()),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.levelCompleteTitle,
                      style: ParchmentText.cormorant(size: 32),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.levelDetailTitle(args.levelNumber),
                      style: ParchmentText.karla(
                        size: 15,
                        color: ParchmentColors.brown,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (args.scoreSyncDeferred)
                      ParchmentNoticeBanner(
                        message: l10n.levelCompleteScoreQueued,
                        tone: ParchmentNoticeTone.info,
                        icon: Icons.cloud_upload_outlined,
                      )
                    else
                      ParchmentCard(
                        child: Column(
                          children: <Widget>[
                            if (args.score != null)
                              Text(
                                l10n.levelCompleteScore(args.score!),
                                style: ParchmentText.cormorant(size: 28),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.levelCompleteAttempts(args.attemptNumber),
                              style: ParchmentText.karla(
                                size: 12,
                                color: ParchmentColors.inkMuted(),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (args.userRank != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.leaderboardYourRankValue(
                                  args.userRank!,
                                  args.score ?? 0,
                                ),
                                style: ParchmentText.karla(size: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_showNotifyPrompt) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      ParchmentCard(
                        title: l10n.levelCompleteNotifyTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              l10n.levelCompleteNotifyBody,
                              style: ParchmentText.karla(size: 13, height: 1.35),
                            ),
                            if (_notifyError != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              ParchmentNoticeBanner(
                                message: _notifyError!,
                                tone: ParchmentNoticeTone.warning,
                                icon: Icons.notifications_off_outlined,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ParchmentPrimaryButton(
                                    label: l10n.levelCompleteNotifyYes,
                                    busy: _notifyBusy,
                                    onPressed: _notifyBusy ? null : _enableReminders,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: ParchmentSecondaryButton(
                                    label: l10n.levelCompleteNotifyNo,
                                    onPressed:
                                        _notifyBusy ? null : _declineReminders,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (args.nextLevelNumber != null)
                      ParchmentPrimaryButton(
                        label: l10n.levelCompleteNextLevel,
                        icon: Icons.play_arrow_rounded,
                        busy: _advancing,
                        onPressed: _advancing
                            ? null
                            : () => _continue(toNextLevel: true),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    ParchmentSecondaryButton(
                      label: l10n.leaderboardTitle,
                      onPressed: _advancing ? null : _viewLeaderboard,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed:
                          _advancing ? null : () => _continue(toNextLevel: false),
                      child: Text(l10n.actionBackToMap),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
