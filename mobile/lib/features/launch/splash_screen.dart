import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';
import '../../state/bootstrap_controller.dart';
import '../../widgets/anointed_wordmark.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';

/// M-01 Splash / launch sequence (design-spec §6 Flow 1).
///
/// Renders the brand mark for as long as the launch checks take, then routes
/// exactly once. Nothing here decides *where* to go — that comes from the
/// server-driven [BootstrapController] phase and step.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final NotificationService notifications = context.read<NotificationService>();
    // Initialises the plugin only — no permission is requested at launch
    // (design-spec §22 rule 1). This is also what captures a cold launch that
    // came from tapping a reminder.
    await notifications.init();

    if (!mounted) return;
    final String? launchTrigger = notifications.consumeLaunchTrigger();
    if (launchTrigger != null) {
      context.read<AnalyticsService>().track(
        'local_notification_opened',
        properties: <String, Object?>{
          'trigger': launchTrigger,
          'entry_screen': 'M-01_splash',
        },
      );
    }

    if (!mounted) return;
    await context.read<BootstrapController>().run();
  }

  void _routeFor(BootstrapController bootstrap) {
    if (_routed) return;

    switch (bootstrap.phase) {
      case BootstrapPhase.loading:
      case BootstrapPhase.networkError:
        return;

      case BootstrapPhase.forceUpgrade:
        _routed = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.forceUpgrade,
          (Route<dynamic> route) => false,
        );
        return;

      case BootstrapPhase.unauthenticated:
        _routed = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.welcome,
          (Route<dynamic> route) => false,
        );
        return;

      case BootstrapPhase.onboarding:
        _routed = true;
        goToStep(context, bootstrap.step);
        return;

      case BootstrapPhase.ready:
        _routed = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.home,
          (Route<dynamic> route) => false,
          arguments: HomeArgs(showSyncFailedToast: bootstrap.startedOffline),
        );
        return;
    }
  }

  Future<void> _retry() async {
    _routed = false;
    await context.read<BootstrapController>().run();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BootstrapController bootstrap = context.watch<BootstrapController>();

    // Routing has to happen after this build completes; doing it inline would
    // mutate the navigator during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _routeFor(bootstrap);
    });

    return Scaffold(
      backgroundColor: ParchmentColors.page,
      body: SafeArea(
        child: bootstrap.phase == BootstrapPhase.networkError
            ? ErrorView(
                title: l10n.errorGenericTitle,
                message: l10n.splashConnectionError,
                icon: Icons.wifi_off_rounded,
                onRetry: _retry,
              )
            : _Brand(caption: l10n.splashCheckingUpdates),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AnointedWordmark(),
          const SizedBox(height: AppSpacing.xxl),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: ParchmentColors.gold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              caption,
              style: ParchmentText.karla(
                size: 13,
                color: ParchmentColors.inkMuted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
