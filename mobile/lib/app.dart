import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/analytics_route_observer.dart';
import 'core/device_context.dart';
import 'core/local_store.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'features/ads/ad_break_screen.dart';
import 'features/auth/phone_sign_up_screen.dart';
import 'features/auth/profile_completion_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/consent/awaiting_email_screen.dart';
import 'features/consent/child_profile_screen.dart';
import 'features/consent/parent_attestation_screen.dart';
import 'features/consent/parent_email_screen.dart';
import 'features/consent/parent_gate_screen.dart';
import 'features/consent/parent_oauth_screen.dart';
import 'features/gameplay/gameplay_screen.dart';
import 'features/gameplay/level_complete_screen.dart';
import 'features/gameplay/level_fail_screen.dart';
import 'features/iap/iap_unlock_screen.dart';
import 'features/iap/purchase_failed_screen.dart';
import 'features/iap/purchase_success_screen.dart';
import 'features/iap/restore_purchase_screen.dart';
import 'features/kids_zone/kids_zone_complete_screen.dart';
import 'features/kids_zone/kids_zone_game_screen.dart';
import 'features/kids_zone/kids_zone_hub_screen.dart';
import 'features/launch/force_upgrade_screen.dart';
import 'features/launch/splash_screen.dart';
import 'features/onboarding/child_notice_screen.dart';
import 'features/onboarding/privacy_terms_screen.dart';
import 'features/practice/practice_gameplay_screen.dart';
import 'features/practice/practice_result_screen.dart';
import 'features/profile/account_deletion_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/support/support_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/kids_zone_audio_service.dart';
import 'services/notification_service.dart';
import 'services/text_to_speech_service.dart';
import 'state/bootstrap_controller.dart';
import 'state/settings_controller.dart';
import 'widgets/brand_background.dart';

/// Root widget: theme, localization, routing, and app-lifecycle bookkeeping.
///
/// Navigator 1.0 with named routes (see core/routes.dart for why).
class AnointedApp extends StatefulWidget {
  const AnointedApp({super.key});

  @override
  State<AnointedApp> createState() => _AnointedAppState();
}

class _AnointedAppState extends State<AnointedApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
        // Transient and common: the notification shade, the app switcher
        // preview, an incoming-call banner. iOS also passes through here on its
        // way to `hidden`, so acting now would stutter the music every time the
        // shade is pulled down.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _onBackgrounded();
    }
  }

  /// Everything the app is making noise with, silenced together.
  ///
  /// Kids Zone music is reachable through its own singleton; read-aloud is a
  /// provider because ranked gameplay shares it. Neither stops on its own when
  /// the app goes away — `audioplayers` and `flutter_tts` both play on over the
  /// lock screen unless told otherwise.
  void _onBackgrounded() {
    unawaited(KidsZoneAudioService.instance.pauseForBackground());
    unawaited(context.read<TextToSpeechService>().stop());
  }

  void _onResumed() {
    // Narration is not resumed on purpose: picking a sentence back up halfway
    // through is worse than the screen simply being quiet, and every game
    // speaks again on its next beat.
    unawaited(KidsZoneAudioService.instance.resumeFromBackground());

    final DeviceContext device = context.read<DeviceContext>();

    // analytics-spec §15: the analytics session id rotates after 30 minutes of
    // inactivity, and a resume past that window is a new session rather than a
    // continuation — so `session_start` is emitted only in that case.
    if (device.sessionExpired) {
      context.read<BootstrapController>().trackForegroundResume();
    }
    device.markActive();

    // design-spec §22: reminders are re-armed from the latest session on every
    // app open, so an active player never receives an inactivity nudge.
    _rescheduleReminders();
  }

  Future<void> _rescheduleReminders() async {
    final NotificationService notifications = context.read<NotificationService>();
    if (!notifications.optedIn) return;

    final LocalStore store = context.read<LocalStore>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int currentLevel = store.currentLevel;

    await notifications.rescheduleForActiveSession(
      currentLevel: currentLevel,
      reminder3dTitle: l10n.notification3dTitle,
      reminder3dBody: l10n.notification3dBody(currentLevel),
      reminder7dTitle: l10n.notification7dTitle,
      reminder7dBody: l10n.notification7dBody,
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDescription,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final AnalyticsRouteObserver routeObserver = context.read<AnalyticsRouteObserver>();

    return MaterialApp(
      onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: <NavigatorObserver>[routeObserver],
      initialRoute: Routes.splash,
      onGenerateRoute: _generateRoute,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        // The OS text scale and the in-app "Large text" toggle compose into one
        // factor here rather than stacking two TextScalers, which would
        // double-scale for a user who has both turned up (design-spec §8).
        final double osScale = media.textScaler.scale(1);
        final double combined =
            (osScale * settings.textScaleMultiplier).clamp(0.85, 2.4);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combined)),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const BrandBackground(),
              if (child != null) child,
            ],
          ),
        );
      },
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final Object? args = settings.arguments;

    switch (settings.name) {
      case Routes.splash:
        return _page(settings, const SplashScreen());

      case Routes.forceUpgrade:
        return _page(settings, const ForceUpgradeScreen());

      case Routes.welcome:
        return _page(settings, const WelcomeScreen());

      case Routes.phoneSignUp:
        return _page(settings, const PhoneSignUpScreen());

      case Routes.signIn:
        return _page(settings, const SignInScreen());

      case Routes.profileCompletion:
        return _page(settings, const ProfileCompletionScreen());

      case Routes.parentGate:
        return _page(settings, const ParentGateScreen());

      case Routes.parentOauth:
        return _page(settings, const ParentOauthScreen());

      case Routes.parentAttestation:
        return _page(
          settings,
          ParentAttestationScreen(
            args: args is AttestationArgs ? args : const AttestationArgs(),
          ),
        );

      case Routes.childProfile:
        return _page(
          settings,
          ChildProfileScreen(args: args as ChildProfileArgs),
        );

      case Routes.parentEmail:
        return _page(settings, const ParentEmailScreen());

      case Routes.awaitingEmail:
        return _page(
          settings,
          AwaitingEmailScreen(args: args as AwaitingEmailArgs),
        );

      case Routes.childNotice:
        return _page(settings, const ChildNoticeScreen());

      case Routes.privacyTerms:
        return _page(settings, const PrivacyTermsScreen());

      case Routes.home:
        return _page(
          settings,
          HomeShell(args: args is HomeArgs ? args : const HomeArgs()),
        );

      case Routes.gameplay:
        return _page(settings, GameplayScreen(args: args as GameplayArgs));

      case Routes.levelComplete:
        return _page(
          settings,
          LevelCompleteScreen(args: args as LevelCompleteArgs),
        );

      case Routes.levelFail:
      case Routes.timerExpired:
        // M-15 and M-16 are the same screen with different copy, so the route
        // name is what distinguishes them for the analytics observer.
        return _page(settings, LevelFailScreen(args: args as LevelFailArgs));

      case Routes.adBreak:
        return _page(settings, AdBreakScreen(args: args as AdBreakArgs));

      case Routes.iapUnlock:
        return _page(settings, IapUnlockScreen(args: args as IapArgs));

      case Routes.purchaseSuccess:
        return _page(settings, PurchaseSuccessScreen(args: args as IapArgs));

      case Routes.purchaseFailed:
        return _page(
          settings,
          PurchaseFailedScreen(args: args as PurchaseFailedArgs),
        );

      case Routes.restorePurchase:
        return _page(settings, const RestorePurchaseScreen());

      case Routes.practiceGameplay:
        return _page(
          settings,
          PracticeGameplayScreen(args: args as PracticeGameplayArgs),
        );

      case Routes.practiceResult:
        return _page(
          settings,
          PracticeResultScreen(args: args as PracticeResultArgs),
        );

      case Routes.kidsZone:
        return _page(settings, const KidsZoneHubScreen());

      case Routes.kidsZoneGameplay:
        return _page(
          settings,
          KidsZoneGameScreen(args: args as KidsZoneGameplayArgs),
        );

      case Routes.kidsZoneComplete:
        return _page(
          settings,
          KidsZoneCompleteScreen(args: args as KidsZoneCompleteArgs),
        );

      case Routes.settings:
        return _page(settings, const SettingsScreen());

      case Routes.accountDeletion:
        return _page(settings, const AccountDeletionScreen());

      case Routes.support:
        return _page(
          settings,
          SupportScreen(args: args is SupportArgs ? args : const SupportArgs()),
        );

      default:
        // An unknown route can only come from a programming error, and silently
        // showing a blank page would hide it. Route to the launch sequence, which
        // re-derives the correct destination from the session.
        return _page(
          const RouteSettings(name: Routes.splash),
          const SplashScreen(),
        );
    }
  }

  Route<dynamic> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (BuildContext context) => child,
    );
  }
}
