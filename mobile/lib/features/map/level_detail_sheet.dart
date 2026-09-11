import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics_route_observer.dart';
import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/screen_ids.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../services/game_repository.dart';
import '../../widgets/gameplay_widgets.dart';
import '../../widgets/state_views.dart';

/// M-12 Level detail (design-spec §1C).
///
/// A bottom sheet rather than a full screen, because it is a decision point
/// rather than a destination — the map stays visible behind it. Resolves to the
/// [LevelDetail] to play, or null if dismissed.
Future<LevelDetail?> showLevelDetailSheet(
  BuildContext context, {
  required int levelNumber,
}) {
  context.read<AnalyticsRouteObserver>().recordScreen(ScreenIds.levelDetail);

  return showModalBottomSheet<LevelDetail>(
    context: context,
    isScrollControlled: true,
    // design-spec §12: sheets are width-capped on tablet instead of stretching.
    constraints: const BoxConstraints(maxWidth: Layout.dialogMaxWidth),
    builder: (BuildContext sheetContext) =>
        _LevelDetailSheet(levelNumber: levelNumber),
  ).whenComplete(() {
    if (context.mounted) {
      context.read<AnalyticsRouteObserver>().recordScreen(ScreenIds.levelMap);
    }
  });
}

class _LevelDetailSheet extends StatefulWidget {
  const _LevelDetailSheet({required this.levelNumber});

  final int levelNumber;

  @override
  State<_LevelDetailSheet> createState() => _LevelDetailSheetState();
}

class _LevelDetailSheetState extends State<_LevelDetailSheet> {
  LevelDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final LevelDetail detail =
          await context.read<GameRepository>().levelDetail(widget.levelNumber);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = error.isOffline;
        _error = error.isOffline ? null : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final LevelDetail? detail = _detail;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              l10n.levelDetailTitle(widget.levelNumber),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (detail == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: <Widget>[
                    Text(
                      _offline ? l10n.errorOfflineBody : (_error ?? l10n.errorGenericBody),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: _load, child: Text(l10n.actionRetry)),
                  ],
                ),
              )
            else
              ..._details(context, l10n, theme, detail),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    LevelDetail detail,
  ) {
    return <Widget>[
      if (detail.title != null && detail.title!.isNotEmpty) ...<Widget>[
        Text(detail.title!, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
      ],
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          Chip(
            avatar: const Icon(Icons.signal_cellular_alt_rounded, size: 16),
            label: Text(
              '${l10n.levelDetailDifficulty}: '
              '${difficultyLabel(l10n, detail.difficultyTier)}',
            ),
          ),
          Chip(
            avatar: const Icon(Icons.timer_outlined, size: 16),
            label: Text(l10n.levelDetailTimer(detail.timerSeconds)),
          ),
          Chip(
            avatar: const Icon(Icons.quiz_outlined, size: 16),
            label: Text(l10n.levelDetailQuestions(detail.questionsPerAttempt)),
          ),
          if (detail.bestScore != null)
            Chip(
              avatar: const Icon(Icons.star_rounded, size: 16),
              label: Text(l10n.levelDetailBestScore(detail.bestScore!)),
            ),
        ],
      ),
      if (detail.availableVariantTypes.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.levelDetailQuestionMix, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (final VariantType type in detail.availableVariantTypes)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(variantTypeIcon(type), size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      variantTypeLabel(l10n, type),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      if (!detail.playable)
        NoticeBanner(
          message: l10n.levelDetailNotPlayable,
          tone: NoticeTone.warning,
          icon: Icons.construction_rounded,
        )
      else if (detail.locked)
        NoticeBanner(
          message: l10n.levelDetailLockedByProgress,
          tone: NoticeTone.info,
          icon: Icons.lock_outline_rounded,
        )
      else
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(detail),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.levelDetailPlay),
        ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.actionClose),
      ),
    ];
  }
}
