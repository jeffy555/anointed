import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/iap_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';

/// M-25 Restore purchase (design-spec §20).
///
/// Two independent recovery routes converge here, which matters because the
/// common support case is "I paid on my old phone": the store replay handles a
/// same-store-account restore, and the server entitlement handles a user who
/// signed in with the same Google/Apple identity on a new device.
///
/// Pops `true` when the unlock is restored.
class RestorePurchaseScreen extends StatefulWidget {
  const RestorePurchaseScreen({super.key});

  @override
  State<RestorePurchaseScreen> createState() => _RestorePurchaseScreenState();
}

class _RestorePurchaseScreenState extends State<RestorePurchaseScreen> {
  bool _busy = false;
  String? _message;
  NoticeTone _tone = NoticeTone.info;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final IapService iap = context.read<IapService>();
    final PurchaseFlowResult result = await iap.restore();
    if (!mounted) return;

    final String outcome = switch (result.status) {
      PurchaseFlowStatus.success || PurchaseFlowStatus.alreadyOwned => 'success',
      PurchaseFlowStatus.nothingToRestore => 'nothing_to_restore',
      _ => 'error',
    };
    context.read<AnalyticsService>().track(
      'purchase_restored',
      properties: <String, Object?>{'outcome': outcome},
    );

    if (result.unlocked) {
      context.read<SessionController>().applyUnlock();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _tone = NoticeTone.success;
        _message = l10n.restorePurchaseSuccess;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _busy = false;
      _tone = result.status == PurchaseFlowStatus.nothingToRestore
          ? NoticeTone.info
          : NoticeTone.warning;
      _message = switch (result.status) {
        PurchaseFlowStatus.nothingToRestore => l10n.restorePurchaseNothing,
        PurchaseFlowStatus.storeUnavailable => l10n.iapStoreUnavailable,
        _ => l10n.restorePurchaseError,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.restorePurchaseTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.restore_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.restorePurchaseBody, style: theme.textTheme.bodyMedium),
                if (_message != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  NoticeBanner(message: _message!, tone: _tone),
                ],
                const SizedBox(height: AppSpacing.xl),
                SubmitButton(
                  label: l10n.restorePurchaseAction,
                  busy: _busy,
                  onPressed: _restore,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  child: Text(l10n.actionClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
