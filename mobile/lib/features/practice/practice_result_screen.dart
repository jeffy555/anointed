import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../services/game_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/state_views.dart';

/// M-20 Practice result (design-spec §1G).
///
/// No score and no leaderboard — practice is explicitly unranked. The screen's
/// job is to steer a confident player back into ranked mode, which is why the
/// "Play this level for real" CTA is primary when that level is actually
/// unlocked for them.
class PracticeResultScreen extends StatefulWidget {
  const PracticeResultScreen({super.key, required this.args});

  final PracticeResultArgs args;

  @override
  State<PracticeResultScreen> createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> {
  bool _busy = false;

  Future<void> _playForReal() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!context.read<SessionController>().canPlay) {
      showAppSnack(context, l10n.levelMapConsentPending);
      return;
    }

    setState(() => _busy = true);
    try {
      final LevelDetail detail = await context
          .read<GameRepository>()
          .levelDetail(widget.args.levelNumber);
      if (!mounted) return;

      if (detail.locked) {
        setState(() => _busy = false);
        await Navigator.of(context).pushNamed(
          Routes.iapUnlock,
          arguments: IapArgs(
            trigger: IapTrigger.lockedLevelTap,
            returnToLevel: widget.args.levelNumber,
          ),
        );
        return;
      }
      if (!detail.playable) {
        setState(() => _busy = false);
        showAppSnack(context, l10n.levelDetailNotPlayable);
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        Routes.gameplay,
        arguments: GameplayArgs(level: detail),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, error.isOffline ? l10n.errorOfflineBody : error.message);
    }
  }

  void _practiceAgain() {
    Navigator.of(context).pushReplacementNamed(
      Routes.practiceGameplay,
      arguments: PracticeGameplayArgs(
        levelNumber: widget.args.levelNumber,
        attemptNumber: widget.args.attemptNumber + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final PracticeResultArgs args = widget.args;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    args.passed
                        ? Icons.check_circle_rounded
                        : Icons.school_rounded,
                    size: 72,
                    color: args.passed
                        ? AppColors.success
                        : theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    args.passed
                        ? l10n.practiceResultPassTitle
                        : l10n.practiceResultFailTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    args.passed
                        ? l10n.practiceResultPassBody(args.totalCount)
                        : l10n.practiceResultFailBody(
                            args.correctCount,
                            args.totalCount,
                          ),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (args.levelUnlockedInMainMode)
                    FilledButton.icon(
                      onPressed: _busy ? null : _playForReal,
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: Text(l10n.practiceResultTryMain),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _practiceAgain,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.practiceResultTryAgain),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  if (args.levelUnlockedInMainMode)
                    OutlinedButton(
                      onPressed: _busy ? null : _practiceAgain,
                      child: Text(l10n.practiceResultTryAgain),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.practiceResultBack),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
