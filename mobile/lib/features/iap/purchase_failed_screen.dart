import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';

/// M-24 Purchase failed (design-spec §20, §14).
///
/// `purchase_failed` is emitted by the IAP service at the moment the store
/// reports the error, so this screen does not re-emit it. The store's raw error
/// code is never shown to the user — it is carried into the support form instead,
/// where an operator can act on it.
class PurchaseFailedScreen extends StatelessWidget {
  const PurchaseFailedScreen({super.key, required this.args});

  final PurchaseFailedArgs args;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseFailedTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.purchaseFailedTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.purchaseFailedBody,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed(
                      Routes.iapUnlock,
                      arguments: IapArgs(trigger: args.trigger),
                    ),
                    child: Text(l10n.actionRetry),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      Routes.support,
                      arguments: SupportArgs(
                        entrySource: 'M-24_purchase_error'
                            '${args.errorCode == null ? '' : ' (${args.errorCode})'}',
                        presetCategory: 'purchase',
                      ),
                    ),
                    child: Text(l10n.actionContactSupport),
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
    );
  }
}
