import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/connectivity.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/content_pack.dart';
import '../../services/analytics_service.dart';
import '../../services/content_service.dart';
import '../../widgets/parchment_ui.dart';
import '../../widgets/state_views.dart';

/// M-18 Practice hub (design-spec §1G, §19).
class PracticeHubScreen extends StatefulWidget {
  const PracticeHubScreen({super.key});

  @override
  State<PracticeHubScreen> createState() => _PracticeHubScreenState();
}

class _PracticeHubScreenState extends State<PracticeHubScreen> {
  bool _syncFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());
  }

  Future<void> _onEnter() async {
    if (!mounted) return;
    context.read<AnalyticsService>().track(
      'practice_mode_started',
      properties: <String, Object?>{
        'connectivity': context.read<ConnectivityService>().label,
      },
    );

    final ContentService content = context.read<ContentService>();
    if (!content.hasUsablePack && !content.isLoading) {
      await content.load();
    }
    if (!mounted) return;

    if (context.read<ConnectivityService>().isOnline) {
      final PackSyncOutcome outcome = await content.syncIfStale();
      if (!mounted) return;
      setState(() => _syncFailed = outcome.error != null);
    }
  }

  Future<void> _retrySync() async {
    setState(() => _syncFailed = false);
    final PackSyncOutcome outcome =
        await context.read<ContentService>().syncIfStale(force: true);
    if (!mounted) return;
    setState(() => _syncFailed = outcome.error != null);
  }

  void _play(int levelNumber) {
    final ContentService content = context.read<ContentService>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!content.isOfflinePracticeLevel(levelNumber)) {
      showAppSnack(context, l10n.practiceLevelOfflineOnly);
      return;
    }
    if (content.questionsFor(levelNumber).isEmpty) {
      showAppSnack(context, l10n.practiceLevelNotReady);
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.practiceGameplay,
      arguments: PracticeGameplayArgs(levelNumber: levelNumber),
    );
  }

  Widget _shell({
    required AppLocalizations l10n,
    required Widget body,
    Widget? trailing,
  }) {
    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ParchmentScreenHeader(
              eyebrow: 'ANOINTED',
              title: l10n.practiceHubTitle,
              trailing: trailing,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ContentService content = context.watch<ContentService>();
    final bool offline = !context.watch<ConnectivityService>().isOnline;
    final ContentPack? pack = content.pack;

    final Widget offlineBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: ParchmentColors.creamDark,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParchmentColors.gold.withOpacity(0.35)),
      ),
      child: Text(
        l10n.practiceOfflineBadge,
        style: ParchmentText.karla(size: 11, weight: FontWeight.w700),
      ),
    );

    if (content.isLoading && pack == null) {
      return _shell(l10n: l10n, body: const LoadingView());
    }

    if (content.isCorrupt) {
      return _shell(
        l10n: l10n,
        body: ErrorView(
          title: l10n.errorGenericTitle,
          message: l10n.practicePackCorrupt,
          icon: Icons.broken_image_outlined,
          secondaryLabel: l10n.actionContactSupport,
          onSecondary: () => Navigator.of(context).pushNamed(
            Routes.support,
            arguments: const SupportArgs(
              entrySource: 'M-18_practice_hub',
              presetCategory: 'gameplay',
            ),
          ),
        ),
      );
    }

    if (pack == null || !pack.isUsable) {
      return _shell(
        l10n: l10n,
        body: EmptyView(
          message: l10n.practiceNoPackOffline,
          icon: Icons.cloud_download_outlined,
          actionLabel: offline ? l10n.practiceNoPackRetry : l10n.actionRetry,
          onAction: _retrySync,
        ),
      );
    }

    final DateTime? published = content.packPublishedAt;

    return _shell(
      l10n: l10n,
      trailing: offlineBadge,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: Layout.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.practiceHubSubhead,
                    style: ParchmentText.karla(size: 14, height: 1.4),
                  ),
                  if (published != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.practiceQuestionsUpdated(
                        DateFormat.yMMMd().format(published.toLocal()),
                      ),
                      style: ParchmentText.karla(
                        size: 12,
                        color: ParchmentColors.inkMuted(),
                      ),
                    ),
                  ],
                  if (content.isDownloading) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ParchmentNoticeBanner(
                      message: l10n.practiceUpdating,
                    ),
                  ],
                  if (_syncFailed && !content.isDownloading) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ParchmentNoticeBanner(
                      message: l10n.practiceUpdateFailed,
                      tone: ParchmentNoticeTone.warning,
                      icon: Icons.sync_problem_rounded,
                      actionLabel: l10n.actionRetry,
                      onAction: _retrySync,
                    ),
                  ],
                  if (content.shouldShowFreshnessBanner &&
                      !content.isDownloading) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ParchmentNoticeBanner(
                      message: l10n.practiceQuestionsUpdated(
                        published == null
                            ? '${content.localContentVersion}'
                            : DateFormat.yMMMd().format(published.toLocal()),
                      ),
                      tone: ParchmentNoticeTone.success,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: Layout.pageInset(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: Layout.isTablet(context) ? 110 : 96,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: content.practiceLevels.length,
                (BuildContext context, int index) {
                  final PackLevel level = content.practiceLevels[index];
                  final bool ready =
                      pack.questionsFor(level.levelNumber).isNotEmpty;
                  return Center(
                    child: ParchmentPracticeTile(
                      levelNumber: level.levelNumber,
                      ready: ready,
                      onTap: () => _play(level.levelNumber),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}
