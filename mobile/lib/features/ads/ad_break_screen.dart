import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/ads_service.dart';

/// M-21 Ad break (design-spec §20).
///
/// A transition screen, not an ad container: the interstitial is a full-screen
/// AdMob surface shown over this. Its only jobs are to explain the pause and to
/// guarantee the player is never stranded — if no ad is available (no fill, SDK
/// unconfigured, or an under-13 account that never initialised the SDK), this
/// forwards immediately.
///
/// Reaching this screen at all already requires [AdsService.shouldShowInterstitial]
/// to have returned true, which is false for every under-13 account.
class AdBreakScreen extends StatefulWidget {
  const AdBreakScreen({super.key, required this.args});

  final AdBreakArgs args;

  @override
  State<AdBreakScreen> createState() => _AdBreakScreenState();
}

class _AdBreakScreenState extends State<AdBreakScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final AdsService ads = context.read<AdsService>();

    // Already preloaded on M-14; this covers the case where the preload did not
    // finish in time and returns false rather than blocking.
    final bool shown = await ads.showInterstitial(
      levelNumber: widget.args.levelNumber,
    );
    if (!mounted) return;
    if (!shown) {
      await ads.disposeAd();
    }
    _forward();
  }

  void _forward() {
    if (!mounted) return;
    switch (widget.args.next) {
      case AdBreakDestination.iapPrompt:
        Navigator.of(context).pushReplacementNamed(
          Routes.iapUnlock,
          arguments: const IapArgs(trigger: IapTrigger.levelFiveComplete),
        );
      case AdBreakDestination.levelMap:
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.home,
          (Route<dynamic> route) => false,
          arguments: const HomeArgs(),
        );
    }
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
            child: ContentColumn(
              maxWidth: 360,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.adBreakTitle,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.adBreakSubtitle,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
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
