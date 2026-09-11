import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/tokens.dart';
import '../features/map/parchment_codex_tokens.dart';
import '../l10n/gen/app_localizations.dart';

/// Centred spinner for a whole-screen load (design-spec §15 "Loading" rows).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String text = label ?? l10n.loadingLabel;
    return Center(
      child: Semantics(
        label: text,
        liveRegion: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error with an optional retry, used for every "API error" state.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Offline variant from design-spec §15.
  factory ErrorView.offline(
    BuildContext context, {
    VoidCallback? onRetry,
    String? message,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ErrorView(
      title: l10n.errorOfflineTitle,
      message: message ?? l10n.errorOfflineBody,
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
    );
  }

  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: Layout.pagePadding(context),
        child: ContentColumn(
          maxWidth: 420,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              if (title != null) ...<Widget>[
                Text(
                  title!,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(retryLabel ?? l10n.actionRetry),
                ),
              ],
              if (onSecondary != null && secondaryLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration-style empty state (M-17 "Be the first!", M-18 no-pack).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: Layout.pagePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.secondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey placeholder block for the skeleton loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurface.withOpacity(0.08);
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(AppRadius.sm)
              : null,
        ),
      ),
    );
  }
}

/// Skeleton rows for list screens (M-17, M-18, admin tables).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: Layout.pagePadding(context),
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        // The whole row is constant — it is a skeleton placeholder, identical
        // for every index — so it is built once rather than per item.
        return const Row(
          children: <Widget>[
            SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(height: 14),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum NoticeTone { info, warning, error, success }

/// Non-blocking inline banner: the practice-pack "Updating…" notice, the
/// gameplay "Connection lost" bar, the pending-consent block on M-11.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = NoticeTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.showProgress = false,
  });

  final String message;
  final NoticeTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // The same four tones ParchmentNoticeBanner uses, so the two banner widgets
    // don't disagree about what "warning" looks like. The former neon
    // #00E676 success also failed to carry its own text on cream.
    final Color base = switch (tone) {
      NoticeTone.info => ParchmentColors.brown,
      NoticeTone.warning => ParchmentColors.current,
      NoticeTone.error => theme.colorScheme.error,
      NoticeTone.success => const Color(0xFF3D7A4A),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: base.withOpacity(0.22),
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: base.withOpacity(0.65), width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            if (showProgress)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: base),
              )
            else
              Icon(icon ?? Icons.info_outline_rounded, size: 20, color: base),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: theme.textTheme.bodySmall),
            ),
            if (onAction != null && actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bordered container used for grouped content across profile/settings/detail.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
        Card(
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

/// One stat in the profile grid.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Shows a snackbar without the caller needing a messenger reference.
void showAppSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
