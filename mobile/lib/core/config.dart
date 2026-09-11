import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Every value can be overridden with `--dart-define`, so a debug build points at
/// a laptop backend and a store build points at production without a code change:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.anointed.app
/// ```
class AppConfig {
  const AppConfig._();

  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base URL for the FastAPI backend.
  ///
  /// The default differs per platform because "localhost" means the device, not
  /// the developer's machine: the Android emulator reaches the host through the
  /// 10.0.2.2 alias, while the iOS simulator shares the host loopback.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// Reasons this build must not be shipped, checked once at boot.
  ///
  /// The defaults above are developer loopback addresses. In a debug build that
  /// is the convenience they exist for; in a release build it is silent
  /// breakage — the app installs, launches, and every request fails with a
  /// connection error that looks like the user's network. A store build must be
  /// pointed at the real backend explicitly:
  ///
  /// ```
  /// flutter build appbundle --dart-define=API_BASE_URL=https://api.anointed.app
  /// ```
  ///
  /// Empty in debug and profile builds, so nothing here affects development.
  static List<String> get releaseConfigErrors {
    if (!kReleaseMode) return const <String>[];
    final List<String> errors = <String>[];
    if (_apiBaseUrlOverride.isEmpty) {
      errors.add(
        'API_BASE_URL is not set, so this build would call the developer '
        'default ($apiBaseUrl). Pass '
        '--dart-define=API_BASE_URL=https://your.api.host',
      );
    } else if (!_apiBaseUrlOverride.startsWith('https://')) {
      errors.add(
        'API_BASE_URL must be https in a release build '
        '(got "$_apiBaseUrlOverride"). Sessions and receipts travel over it.',
      );
    }
    return errors;
  }

  /// Throws if this release build is misconfigured. Called from `main()` before
  /// the first frame: failing at launch is loud, and a build that talks to
  /// nothing is worse than one that does not start.
  static void assertReleaseConfig() {
    final List<String> errors = releaseConfigErrors;
    if (errors.isEmpty) return;
    throw StateError(
      'Release build is misconfigured:\n  - ${errors.join('\n  - ')}',
    );
  }

  /// When true and OAuth is not configured on the client, fall back to dev tokens.
  /// Disabled automatically when [googleServerClientId] is set — the backend
  /// verifies real JWTs only in that case and rejects dev tokens.
  static bool get devOAuthFallback =>
      !googleOAuthConfigured &&
      const bool.fromEnvironment('DEV_OAUTH_FALLBACK', defaultValue: !kReleaseMode);

  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue:
        '534331923421-hkmkr6udcsjdpnpmqtfmn9cn1c1hns88.apps.googleusercontent.com',
  );

  /// Web client ID — required so Google returns an ID token the backend can verify.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '534331923421-c28ata5t344743749pl7epediju17mju.apps.googleusercontent.com',
  );

  static bool get googleOAuthConfigured => googleServerClientId.isNotEmpty;

  /// Analytics batching (analytics-spec §15: batch and flush on connectivity).
  static const Duration analyticsFlushInterval = Duration(seconds: 20);
  static const int analyticsBatchSize = 20;
  static const int analyticsQueueCap = 500;

  /// design-spec §11: M-06E polls consent status every 5s.
  static const Duration consentPollInterval = Duration(seconds: 5);

  /// design-spec §19: re-check the content manifest on M-18 entry if the last
  /// check was more than 24h ago.
  static const Duration manifestRecheckInterval = Duration(hours: 24);

  /// Offline practice ships only the free-tier levels (matches backend
  /// `free_tier_max_level` and the practice content pack filter).
  static const int offlinePracticeMaxLevel = 5;

  /// Leaderboard is polled, not realtime (requirements.json backend.realtime).
  static const Duration leaderboardRefreshInterval = Duration(minutes: 3);

  /// design-spec §15 M-21: at most a 2 second wait for an interstitial before
  /// the ad break is silently skipped.
  static const Duration adLoadTimeout = Duration(seconds: 2);

  /// design-spec §21: answers faster than this are rejected server-side as
  /// implausible. The client uses it only to avoid sending a doomed request.
  static const int answerTimeFloorMs = 800;

  static const Duration apiTimeout = Duration(seconds: 20);

  /// Local reminder schedule (design-spec §22).
  static const Duration inactivityNudge1 = Duration(days: 3);
  static const Duration inactivityNudge2 = Duration(days: 7);

  /// Support address for the pre-authentication path only.
  ///
  /// `/v1/account/faq` and `/v1/account/support` both require a session, so a
  /// user who cannot sign in at all (design-spec §14 links M-10 to support) has
  /// no way to read the server's address. Mirrors the backend's
  /// `settings.support_email` default; the signed-in path always uses the value
  /// the API returns rather than this constant.
  static const String fallbackSupportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@anointed.app',
  );

  /// Legal URLs are served per-account (`privacy_policy_url`,
  /// `terms_of_service_url`) so counsel can revise them without an app release.
  /// These mirror the backend defaults and are used only when the profile cache
  /// is empty — e.g. M-27 opened before M-26 has ever loaded.
  static const String fallbackPrivacyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://anointed.app/privacy',
  );
  static const String fallbackTermsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://anointed.app/terms',
  );
}
