import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/level.dart';
import '../../services/analytics_service.dart';
import '../../services/game_repository.dart';
import '../../services/iap_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';

/// M-22 IAP unlock prompt (design-spec §20).
///
/// One non-consumable SKU for levels 6-100, priced by the store. The value copy
/// is aimed at the paying adult ("Support your child's Bible learning") while
/// staying honest that the free tier and practice mode remain free.
///
/// Pops `true` when the unlock succeeded, so the caller (level map or practice
/// result) can refresh instead of guessing.
class IapUnlockScreen extends StatefulWidget {
  const IapUnlockScreen({super.key, required this.args});

  final IapArgs args;

  @override
  State<IapUnlockScreen> createState() => _IapUnlockScreenState();
}

class _IapUnlockScreenState extends State<IapUnlockScreen> {
  bool _busy = false;
  String? _notice;
  bool _promptTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final IapService iap = context.read<IapService>();
    await iap.ensureReady();
    if (!mounted || _promptTracked) return;
    _promptTracked = true;
    context.read<AnalyticsService>().track(
      'iap_prompt_shown',
      properties: <String, Object?>{
        'trigger': widget.args.trigger.wireValue,
        'store_price_loaded': iap.storePriceLoaded,
      },
    );
  }

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _notice = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final IapService iap = context.read<IapService>();
    final PurchaseFlowResult result =
        await iap.buy(trigger: widget.args.trigger.wireValue);
    if (!mounted) return;

    switch (result.status) {
      case PurchaseFlowStatus.success:
      case PurchaseFlowStatus.alreadyOwned:
        context.read<SessionController>().applyUnlock();
        await Navigator.of(context).pushReplacementNamed(
          Routes.purchaseSuccess,
          arguments: widget.args,
        );
        return;

      case PurchaseFlowStatus.cancelled:
        setState(() {
          _busy = false;
          _notice = l10n.purchaseCancelledNotice;
        });
        return;

      case PurchaseFlowStatus.storeUnavailable:
        // Expected on an emulator or before the SKU exists in the store console.
        setState(() {
          _busy = false;
          _notice = l10n.iapStoreUnavailable;
        });
        return;

      case PurchaseFlowStatus.nothingToRestore:
      case PurchaseFlowStatus.failed:
        setState(() => _busy = false);
        await Navigator.of(context).pushReplacementNamed(
          Routes.purchaseFailed,
          arguments: PurchaseFailedArgs(
            trigger: widget.args.trigger,
            errorCode: result.errorCode,
          ),
        );
        return;
    }
  }

  Future<void> _later() async {
    context.read<AnalyticsService>().track(
      'purchase_cancelled',
      properties: <String, Object?>{
        'store': context.read<IapService>().storeName,
        'trigger': widget.args.trigger.wireValue,
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  /// Only reachable from the level-map path, where a specific locked level was
  /// tapped: after a successful unlock that level should open.
  Future<void> _openReturnLevel() async {
    final int? levelNumber = widget.args.returnToLevel;
    if (levelNumber == null) {
      Navigator.of(context).pop(true);
      return;
    }
    try {
      final LevelDetail detail =
          await context.read<GameRepository>().levelDetail(levelNumber);
      if (!mounted) return;
      if (detail.playable && !detail.locked) {
        Navigator.of(context).pushReplacementNamed(
          Routes.gameplay,
          arguments: GameplayArgs(level: detail),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException {
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final IapService iap = context.watch<IapService>();

    final String price = iap.displayPrice;
    final bool priceReady = price.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.iapUnlockTitle(iap.unlockFrom, iap.unlockTo)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.lock_open_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.iapUnlockHeadline,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.iapUnlockBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Benefit(text: l10n.iapUnlockBenefitLevels),
                      _Benefit(text: l10n.iapUnlockBenefitOneTime),
                      _Benefit(text: l10n.iapUnlockBenefitPractice),
                    ],
                  ),
                ),
                if (_notice != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(
                    message: _notice!,
                    tone: NoticeTone.warning,
                    icon: Icons.info_outline_rounded,
                    actionLabel: l10n.actionContactSupport,
                    onAction: () => Navigator.of(context).pushNamed(
                      Routes.support,
                      arguments: const SupportArgs(
                        entrySource: 'M-22_iap_unlock',
                        presetCategory: 'purchase',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SubmitButton(
                  label: priceReady
                      ? l10n.iapUnlockBuyAction(price)
                      : l10n.iapUnlockPriceLoading,
                  icon: Icons.shopping_bag_outlined,
                  busy: _busy,
                  onPressed: priceReady ? _buy : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : _later,
                  child: Text(l10n.iapUnlockLater),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final SessionController session =
                              context.read<SessionController>();
                          final bool? restored = await Navigator.of(context)
                              .pushNamed<bool>(Routes.restorePurchase);
                          if (restored != true || !mounted) return;
                          session.applyUnlock();
                          await _openReturnLevel();
                        },
                  child: Text(l10n.restorePurchaseAction),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded,
              size: 20, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
