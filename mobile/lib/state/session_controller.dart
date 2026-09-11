import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/local_store.dart';
import '../models/account.dart';
import '../models/session.dart';
import '../services/account_repository.dart';
import '../services/analytics_service.dart';
import '../services/auth_repository.dart';
import '../services/crash_reporting.dart';
import '../services/kids_zone_repository.dart';
import '../services/oauth_provider_service.dart';

/// Owns the signed-in session: the bearer token, the current [SessionUser], and
/// the server-decided onboarding step.
///
/// Every mutation funnels through here so three things stay in lockstep with the
/// account state: the API client's auth header, the analytics under-13 gate, and
/// the Crashlytics user id.
class SessionController extends ChangeNotifier {
  SessionController({
    required ApiClient api,
    required AuthRepository auth,
    required AccountRepository account,
    required LocalStore store,
    required AnalyticsService analytics,
    required OAuthProviderService oauth,
    required KidsZoneRepository kidsZone,
  })  : _api = api,
        _auth = auth,
        _account = account,
        _store = store,
        _analytics = analytics,
        _oauth = oauth,
        _kidsZone = kidsZone {
    _api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient _api;
  final AuthRepository _auth;
  final AccountRepository _account;
  final LocalStore _store;
  final AnalyticsService _analytics;
  final OAuthProviderService _oauth;
  final KidsZoneRepository _kidsZone;

  SessionUser? _user;
  OnboardingStep _nextStep = OnboardingStep.levelMap;
  bool _hasToken = false;

  SessionUser? get user => _user;
  OnboardingStep get nextStep => _nextStep;
  bool get isSignedIn => _hasToken && _user != null;

  /// True while a token exists but the session has not been fetched yet.
  bool get hasStoredToken => _hasToken;

  bool get isUnder13 => _user?.isUnder13 ?? false;
  bool get canPlay => _user?.canPlay ?? false;
  bool get adsPermitted => _user?.adsPermitted ?? false;

  /// Restores the token from secure storage. Does not hit the network.
  Future<void> restoreToken() async {
    final String? token = await _store.readSessionToken();
    if (token != null && token.isNotEmpty) {
      _api.setSessionToken(token);
      _hasToken = true;
    }
  }

  /// M-01 routing: refreshes the session and returns the step to route to.
  /// Returns null when there is no usable session.
  Future<OnboardingStep?> refresh() async {
    if (!_hasToken) return null;
    try {
      final SessionState state = await _auth.currentSession();
      _apply(state.user, state.nextStep);
      return state.nextStep;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await clear();
        return null;
      }
      // Offline or a server hiccup: keep whatever we knew last so the map can
      // render from cache (design-spec §15 M-11) rather than bouncing to Welcome.
      rethrow;
    }
  }

  Future<OnboardingStep> signInWithOAuth(OAuthCredential credential, {int? age}) async {
    final AuthResult result = await _auth.signInWithOAuth(credential, age: age);
    await _persist(result);
    return result.nextStep;
  }

  Future<OnboardingStep> phoneSignUp({
    required String mobile,
    required String name,
    required int age,
  }) async {
    final AuthResult result =
        await _auth.phoneSignUp(mobile: mobile, name: name, age: age);
    await _persist(result);
    return result.nextStep;
  }

  Future<OnboardingStep> phoneSignIn({
    required String mobile,
    required String name,
  }) async {
    final AuthResult result = await _auth.phoneSignIn(mobile: mobile, name: name);
    await _persist(result);
    return result.nextStep;
  }

  /// The response's `next_step` *is* the M-05 age-gate decision.
  Future<OnboardingStep> completeProfile({
    required String name,
    required int age,
  }) async {
    final AuthResult result = await _auth.completeProfile(name: name, age: age);
    await _persist(result);
    return result.nextStep;
  }

  Future<OnboardingStep> acceptPrivacy() async {
    final SessionState state = await _auth.acceptPrivacy();
    _apply(state.user, state.nextStep);
    return state.nextStep;
  }

  /// Applies a session update produced by another repository (consent flow).
  void applySessionState(SessionState state) => _apply(state.user, state.nextStep);

  /// Keeps the locally held user in step with a profile fetch, so the map and
  /// profile tabs cannot disagree about unlock state.
  void applyProfile(UserProfile profile) {
    final SessionUser? current = _user;
    if (current == null) return;
    _apply(
      current.copyWith(
        name: profile.name,
        notificationsOptIn: profile.notificationsOptIn,
        hasUnlock: profile.hasUnlock,
        highestLevelCompleted: profile.highestLevelCompleted,
        levelsCompletedCount: profile.levelsCompleted,
      ),
      _nextStep,
    );
  }

  void applyProgress({required int highestLevelCompleted, required int levelsCompleted}) {
    final SessionUser? current = _user;
    if (current == null) return;
    _apply(
      current.copyWith(
        highestLevelCompleted: highestLevelCompleted,
        levelsCompletedCount: levelsCompleted,
      ),
      _nextStep,
    );
    _store.setCurrentLevel(highestLevelCompleted + 1);
  }

  void applyUnlock() {
    final SessionUser? current = _user;
    if (current == null) return;
    _apply(current.copyWith(hasUnlock: true), _nextStep);
  }

  void applyNotificationsOptIn(bool value) {
    final SessionUser? current = _user;
    if (current == null) return;
    _apply(current.copyWith(notificationsOptIn: value), _nextStep);
  }

  /// M-30.
  Future<void> signOut() async {
    // Flush Kids Zone progress before clear() wipes it. Stars are written
    // locally the moment a stop is finished and synced opportunistically after,
    // so a child who played offline and then signed out once back online would
    // otherwise lose every star earned in between — the device copy is deleted
    // here and the server never heard about it. Failure is fine and ignored
    // inside sync(): it means the progress was already unreachable.
    await _kidsZone.sync();

    try {
      await _auth.signOut();
    } on ApiException {
      // The token is stateless, so a failed call does not keep the user signed
      // in — the local clear below is what actually ends the session.
    }
    await _oauth.signOutProviders();
    await clear();
  }

  /// M-29c. The account is already gone server-side when this is called.
  Future<DeletionResult> deleteAccount() async {
    final DeletionResult result = await _account.deleteAccount();
    await _oauth.signOutProviders();
    await clear();
    return result;
  }

  Future<void> clear() async {
    _user = null;
    _hasToken = false;
    _nextStep = OnboardingStep.levelMap;
    _api.setSessionToken(null);
    await _store.clearAccountScopedState();
    _analytics.setAccountStatus(null);
    await CrashReporting.setUserId(null);
    notifyListeners();
  }

  Future<void> _persist(AuthResult result) async {
    _api.setSessionToken(result.sessionToken);
    await _store.writeSessionToken(result.sessionToken);
    _hasToken = true;
    _apply(result.user, result.nextStep);
  }

  void _apply(SessionUser user, OnboardingStep step) {
    _user = user;
    _nextStep = step;
    _analytics.setAccountStatus(user.accountStatus);
    _store.setCurrentLevel(user.currentLevel);
    CrashReporting.setUserId(user.id);
    notifyListeners();
  }

  void _handleUnauthorized() {
    // Fired from inside a request. Only drop local state; the screen that made
    // the call surfaces the error and the router sends the user to Welcome.
    if (!_hasToken) return;
    clear();
  }
}
