import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';

/// M-15 Level fail and M-16 Timer expired (design-spec §1D).
///
/// One screen, two sets of copy, because the recovery is identical and the only
/// real difference is *why* the attempt ended. Critically, the correct answer is
/// never shown: design-spec §1D makes replay the way to learn it, so a fail
/// screen that revealed it would remove the reason to try again.
class LevelFailScreen extends StatelessWidget {
  const LevelFailScreen({super.key, required this.args});

  final LevelFailArgs args;

  bool get _timerExpired => args.reason == FailReason.timerExpired;

  void _tryAgain(BuildContext context) {
    context.read<AnalyticsService>().track(
      'level_restarted',
      properties: <String, Object?>{
        'level_id': args.level.levelNumber,
        'attempt_number': args.attemptNumber + 1,
        'fail_reason': args.analyticsReason,
      },
    );
    // Replaces rather than pushes so repeated retries cannot grow the stack.
    Navigator.of(context).pushReplacementNamed(
      Routes.gameplay,
      arguments: GameplayArgs(level: args.level),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ContentColumn(
                maxWidth: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      _timerExpired
                          ? Icons.timer_off_rounded
                          : Icons.sentiment_neutral_rounded,
                      size: 72,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _timerExpired ? l10n.timerExpiredTitle : l10n.levelFailTitle,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _timerExpired ? l10n.timerExpiredBody : l10n.levelFailBody,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.gameplayProgress(
                        args.questionIndexAtFail + 1,
                        args.level.questionsPerAttempt,
                      ),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => _tryAgain(context),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.levelFailAction),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.actionBackToMap),
                    ),
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
