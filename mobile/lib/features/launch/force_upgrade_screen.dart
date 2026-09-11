import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/device_context.dart';
import '../../core/link_launcher.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/version_info.dart';
import '../../services/analytics_service.dart';
import '../../state/bootstrap_controller.dart';
import '../../widgets/state_views.dart';

/// M-02 Force-upgrade (design-spec §16).
///
/// A hard block: no back navigation, no dismiss, no other route reachable. The
/// only action is the store link, which is why this screen is pushed with the
/// whole stack cleared.
class ForceUpgradeScreen extends StatefulWidget {
  const ForceUpgradeScreen({super.key});

  @override
  State<ForceUpgradeScreen> createState() => _ForceUpgradeScreenState();
}

class _ForceUpgradeScreenState extends State<ForceUpgradeScreen> {
  bool _storeFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final MinimumVersion? upgrade = context.read<BootstrapController>().upgrade;
      context.read<AnalyticsService>().track(
        'force_upgrade_shown',
        properties: <String, Object?>{
          'installed_version': context.read<DeviceContext>().appVersion,
          'minimum_version': upgrade?.minimumVersion,
          'platform': context.read<DeviceContext>().platform,
        },
      );
    });
  }

  Future<void> _openStore(MinimumVersion? upgrade) async {
    final bool opened = await LinkLauncher.openStore(
      appStoreUrl: upgrade?.appStoreUrl ?? '',
      playStoreUrl: upgrade?.playStoreUrl ?? '',
    );
    if (!mounted) return;
    setState(() => _storeFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final MinimumVersion? upgrade = context.watch<BootstrapController>().upgrade;

    return PopScope(
      // design-spec §16: the gate cannot be dismissed, including with the
      // Android system back gesture.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ContentColumn(
                maxWidth: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.system_update_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.forceUpgradeTitle,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.forceUpgradeBody,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (upgrade?.releaseNotes != null &&
                        upgrade!.releaseNotes!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      SectionCard(
                        title: l10n.forceUpgradeReleaseNotesLabel,
                        child: Text(
                          upgrade.releaseNotes!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: () => _openStore(upgrade),
                      child: Text(l10n.actionUpdateNow),
                    ),
                    if (_storeFailed) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      NoticeBanner(
                        message: l10n.forceUpgradeStoreUnavailable,
                        tone: NoticeTone.warning,
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
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
