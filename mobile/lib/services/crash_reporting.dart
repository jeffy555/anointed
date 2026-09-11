import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Crashlytics initialisation (`techStack.crashReporting`).
///
/// Entirely optional at runtime. `Firebase.initializeApp()` reads its options
/// from the native config file — `android/app/google-services.json` on Android,
/// `ios/Runner/GoogleService-Info.plist` on iOS — and throws when that file is
/// absent. Both are gitignored placeholders in this scaffold, so this class
/// treats the failure as "crash reporting is off" and the app runs normally.
///
/// The Android Gradle plugin that consumes google-services.json is applied only
/// when the file exists (see android/app/build.gradle), so an absent config is a
/// no-op at build time too, not a build failure.
class CrashReporting {
  CrashReporting._();

  static bool _enabled = false;

  /// True when Crashlytics is actually receiving reports.
  static bool get isEnabled => _enabled;

  /// Initialises Firebase and installs the global error handlers, then runs [body]
  /// inside a zone whose uncaught errors are reported.
  ///
  /// Handlers are installed *before* the app runs so a crash during the first
  /// frame is still captured.
  static Future<void> runGuarded(FutureOr<void> Function() body) async {
    await _tryInitialise();

    if (!_enabled) {
      // Keep Flutter's own console reporting rather than swallowing errors.
      await body();
      return;
    }

    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousOnError?.call(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await body();
  }

  static Future<void> _tryInitialise() async {
    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      _enabled = true;
    } on Object catch (error) {
      _enabled = false;
      if (kDebugMode) {
        debugPrint(
          'Crash reporting disabled: no Firebase config found ($error). '
          'Drop google-services.json / GoogleService-Info.plist in to enable it.',
        );
      }
    }
  }

  /// Attaches the opaque user id so a crash can be correlated with a session.
  ///
  /// analytics-spec §2 forbids PII in telemetry, so only the internal UUID is
  /// ever set here — never name, mobile number, or email.
  static Future<void> setUserId(String? userId) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } on Object {
      // Non-fatal: the crash report is still useful without the correlation id.
    }
  }

  static Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason, fatal: false);
    } on Object {
      // Ignored by design: reporting a failure to report is not actionable.
    }
  }
}
