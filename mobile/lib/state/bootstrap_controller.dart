import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/connectivity.dart';
import '../core/local_store.dart';
import '../models/session.dart';
import '../models/version_info.dart';
import '../services/analytics_service.dart';
import '../services/content_service.dart';
import '../services/version_repository.dart';
import 'session_controller.dart';

enum BootstrapPhase {
  loading,

  /// M-02 — blocks all navigation.
  forceUpgrade,

  /// No usable session: route to M-03.
  unauthenticated,

  /// Signed in but onboarding is unfinished; route by [BootstrapController.step].
  onboarding,

  /// Signed in and past onboarding: M-11.
  ready,

  /// The version check and the session refresh both failed with no cached
  /// session to fall back on. design-spec §15 M-01 offers a Retry.
  networkError,
}

/// The M-01 launch sequence (design-spec §6 Flow 1).
///
/// Order matters: the version gate runs before anything else so a build that is
/// below the minimum never issues other API calls, then the session decides
/// routing, then the non-blocking background work starts.
class BootstrapController extends ChangeNotifier {
  BootstrapController({
    required SessionController session,
    required VersionRepository version,
    required ContentService content,
    required ConnectivityService connectivity,
    required AnalyticsService analytics,
    required LocalStore store,
  })  : _session = session,
        _version = version,
        _content = content,
        _connectivity = connectivity,
        _analytics = analytics,
        _store = store;

  final SessionController _session;
  final VersionRepository _version;
  final ContentService _content;
  final ConnectivityService _connectivity;
  final AnalyticsService _analytics;
  final LocalStore _store;

  BootstrapPhase _phase = BootstrapPhase.loading;
  MinimumVersion? _upgrade;
  OnboardingStep _step = OnboardingStep.levelMap;
  bool _startedOffline = false;

  BootstrapPhase get phase => _phase;
  MinimumVersion? get upgrade => _upgrade;
  OnboardingStep get step => _step;

  /// True when the session could not be refreshed and the app opened on cached
  /// data. Screens use it to show their offline/stale states.
  bool get startedOffline => _startedOffline;

  Future<void> run() async {
    _phase = BootstrapPhase.loading;
    _startedOffline = false;
    notifyListeners();

    // 1 — Force-upgrade gate. A check that cannot complete lets the app open
    // (design-spec §16), but a previously confirmed block is still honoured.
    final MinimumVersion? version = await _version.check();
    if (version != null && version.forceUpgradeRequired) {
      _upgrade = version;
      _phase = BootstrapPhase.forceUpgrade;
      notifyListeners();
      return;
    }

    // 2 — Session.
    await _session.restoreToken();
    if (!_session.hasStoredToken) {
      // No account yet, so the server cannot record session_start for this launch.
      _analytics.track('session_start', properties: <String, Object?>{
        'is_new_user': true,
        'launch_source': 'cold_launch',
        'auth_provider_linked': 'none',
        'account_status': null,
        'connectivity': _connectivity.label,
      });
      _phase = BootstrapPhase.unauthenticated;
      notifyListeners();
      await _loadContentPack();
      return;
    }

    try {
      final OnboardingStep? step = await _session.refresh();
      if (step == null) {
        _phase = BootstrapPhase.unauthenticated;
        notifyListeners();
        await _loadContentPack();
        return;
      }
      _step = step;
      _phase = step == OnboardingStep.levelMap
          ? BootstrapPhase.ready
          : BootstrapPhase.onboarding;
      await _store.setLastSessionAt(DateTime.now());
    } on ApiException catch (error) {
      if (!error.isOffline) {
        _phase = BootstrapPhase.networkError;
        notifyListeners();
        return;
      }
      // Offline with a stored token: open onto the map and let it render from
      // cache rather than pretending the user is signed out.
      _startedOffline = true;
      _step = OnboardingStep.levelMap;
      _phase = BootstrapPhase.ready;
    }

    notifyListeners();
    await _loadContentPack();
  }

  /// Practice pack load + background refresh. Deliberately awaited *after* the
  /// phase is published so it never delays first paint.
  Future<void> _loadContentPack() async {
    await _content.load();
    if (_connectivity.isOnline && _session.hasStoredToken) {
      // Fire and forget: a stale pack is playable, so nothing waits on this.
      _content.syncIfStale().catchError((Object error) {
        if (kDebugMode) debugPrint('content sync failed: $error');
        return const PackSyncOutcome.upToDate();
      });
    }
  }

  /// Records a foreground resume after the analytics session window lapsed.
  void trackForegroundResume() {
    final SessionUser? user = _session.user;
    _analytics.track('session_start', properties: <String, Object?>{
      'is_new_user': false,
      'launch_source': 'foreground_resume',
      'auth_provider_linked': user?.primaryAuthProvider ?? 'none',
      'account_status': user?.accountStatus.wireValue,
      'connectivity': _connectivity.label,
    });
  }
}
