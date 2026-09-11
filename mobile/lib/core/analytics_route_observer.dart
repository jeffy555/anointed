import 'package:flutter/widgets.dart';

import '../services/analytics_service.dart';
import 'routes.dart';
import 'screen_ids.dart';

/// Emits `screen_view` on every navigation (analytics-spec §3).
///
/// Route names are mapped to the design-spec screen ids rather than reported
/// raw, because analytics-spec §3 requires `screen_name` to be the screen id
/// (`M-11_level_map`), and those ids are an analytics contract that must not
/// drift when a route path is renamed.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  static const Map<String, String> _screenIdByRoute = <String, String>{
    Routes.splash: ScreenIds.splash,
    Routes.forceUpgrade: ScreenIds.forceUpgrade,
    Routes.welcome: ScreenIds.welcome,
    Routes.phoneSignUp: ScreenIds.phoneSignUp,
    Routes.signIn: ScreenIds.signIn,
    Routes.profileCompletion: ScreenIds.profileCompletion,
    Routes.parentGate: ScreenIds.parentGate,
    Routes.parentOauth: ScreenIds.parentOauth,
    Routes.parentAttestation: ScreenIds.parentAttestation,
    Routes.childProfile: ScreenIds.childProfile,
    Routes.parentEmail: ScreenIds.parentEmail,
    Routes.awaitingEmail: ScreenIds.awaitingEmail,
    Routes.childNotice: ScreenIds.childNotice,
    Routes.privacyTerms: ScreenIds.privacyTerms,
    Routes.gameplay: ScreenIds.gameplay,
    Routes.levelComplete: ScreenIds.levelComplete,
    Routes.levelFail: ScreenIds.levelFail,
    Routes.timerExpired: ScreenIds.timerExpired,
    Routes.adBreak: ScreenIds.adBreak,
    Routes.iapUnlock: ScreenIds.iapUnlock,
    Routes.purchaseSuccess: ScreenIds.purchaseSuccess,
    Routes.purchaseFailed: ScreenIds.purchaseFailed,
    Routes.restorePurchase: ScreenIds.restorePurchase,
    Routes.practiceGameplay: ScreenIds.practiceGameplay,
    Routes.practiceResult: ScreenIds.practiceResult,
    Routes.kidsZone: ScreenIds.kidsZoneHub,
    Routes.kidsZoneGameplay: ScreenIds.kidsZoneGameplay,
    Routes.kidsZoneComplete: ScreenIds.kidsZoneComplete,
    Routes.settings: ScreenIds.settings,
    Routes.accountDeletion: ScreenIds.accountDeletion,
    Routes.support: ScreenIds.support,
  };

  final AnalyticsService _analytics;

  String? _currentScreen;
  DateTime _enteredAt = DateTime.now();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // After a pop the user is looking at the route underneath, so that is the
    // screen to report — not the one that just went away.
    _record(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  /// Tab switches inside the home shell and the M-12 bottom sheet are screen
  /// transitions too; they report themselves through this.
  void recordScreen(String screenName) => _emit(screenName);

  void _record(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    if (name == null) return;
    final String? screenId = _screenIdByRoute[name];
    if (screenId == null) return;
    _emit(screenId);
  }

  void _emit(String screenId) {
    if (screenId == _currentScreen) return;
    final DateTime now = DateTime.now();
    _analytics.trackScreenView(
      screenName: screenId,
      previousScreen: _currentScreen,
      timeOnPreviousScreenMs:
          _currentScreen == null ? 0 : now.difference(_enteredAt).inMilliseconds,
    );
    _currentScreen = screenId;
    _enteredAt = now;
  }
}
