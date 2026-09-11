import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../services/game_repository.dart';
import '../../services/iap_service.dart';

/// M-23 Purchase success (design-spec §20).
///
/// `purchase_completed` is emitted server-side by the receipt-validation
/// endpoint, so this screen only confirms and routes — a client-side duplicate
/// would double-count the conversion funnel.
class PurchaseSuccessScreen extends StatefulWidget {
  const PurchaseSuccessScreen({super.key, required this.args});

  final IapArgs args;

  @override
  State<PurchaseSuccessScreen> createState() => _PurchaseSuccessScreenState();
}

class _PurchaseSuccessScreenState extends State<PurchaseSuccessScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    final int? levelNumber = widget.args.returnToLevel;

    if (levelNumber != null) {
      try {
        final LevelDetail detail =
            await context.read<GameRepository>().levelDetail(levelNumber);
        if (!mounted) return;
        if (detail.playable && !detail.locked) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.gameplay,
            (Route<dynamic> route) => route.settings.name == Routes.home,
            arguments: GameplayArgs(level: detail),
          );
          return;
        }
      } on ApiException {
        // Fall through to the map, which will show the now-unlocked levels.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.home,
      (Route<dynamic> route) => false,
      arguments: const HomeArgs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final IapService iap = context.read<IapService>();

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
                    const Icon(
                      Icons.celebration_rounded,
                      size: 72,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.purchaseSuccessTitle,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.purchaseSuccessBody(iap.unlockFrom, iap.unlockTo),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _continue,
                      child: Text(l10n.purchaseSuccessAction),
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
