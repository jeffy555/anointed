import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'local_store.dart';

/// Client metadata for the analytics envelope (analytics-spec §2) and the
/// abuse controls in design-spec §21. Sent as `X-*` headers on every request.
class DeviceContext {
  DeviceContext._({
    required this.installId,
    required this.appVersion,
    required this.buildNumber,
    required this.osVersion,
    required this.deviceType,
    required this.platform,
  });

  final String installId;
  final String appVersion;
  final String buildNumber;
  final String osVersion;

  /// `phone` or `tablet` — analytics-spec §2 device_type.
  final String deviceType;

  /// `ios` or `android`, matching the backend `Platform` enum.
  final String platform;

  /// analytics-spec §15: generated on app open, rotated after 30 min inactivity.
  String _sessionId = const Uuid().v4();
  DateTime _lastActivity = DateTime.now();

  static const Duration _sessionIdleWindow = Duration(minutes: 30);

  String get sessionId {
    if (DateTime.now().difference(_lastActivity) > _sessionIdleWindow) {
      _sessionId = const Uuid().v4();
    }
    _lastActivity = DateTime.now();
    return _sessionId;
  }

  /// True when the app has been idle long enough that the next [sessionId] read
  /// will start a new analytics session. Used to decide whether a resume should
  /// emit `session_start`.
  bool get sessionExpired =>
      DateTime.now().difference(_lastActivity) > _sessionIdleWindow;

  void markActive() => _lastActivity = DateTime.now();

  static Future<DeviceContext> resolve(LocalStore store) async {
    final PackageInfo package = await PackageInfo.fromPlatform();
    String osVersion = 'unknown';
    String deviceType = 'phone';
    String platform = 'android';

    try {
      final DeviceInfoPlugin info = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isIOS) {
        platform = 'ios';
        final IosDeviceInfo ios = await info.iosInfo;
        osVersion = '${ios.systemName} ${ios.systemVersion}';
        deviceType = ios.model.toLowerCase().contains('ipad') ? 'tablet' : 'phone';
      } else if (!kIsWeb && Platform.isAndroid) {
        platform = 'android';
        final AndroidDeviceInfo android = await info.androidInfo;
        osVersion = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
        // Android has no device-class API. The shortest-side heuristic used for
        // layout lives in Layout.isTablet; here the physical screen size from the
        // display metrics is the closest equivalent available off the widget tree.
        final double shortestSideDp = _shortestSideDp(android);
        deviceType = shortestSideDp >= 600 ? 'tablet' : 'phone';
      }
    } on Object {
      // Device info is telemetry only. Losing it must never block launch, so the
      // defaults above stand and the envelope simply carries "unknown".
    }

    return DeviceContext._(
      installId: store.installId(),
      appVersion: package.version,
      buildNumber: package.buildNumber,
      osVersion: osVersion,
      deviceType: deviceType,
      platform: platform,
    );
  }

  static double _shortestSideDp(AndroidDeviceInfo android) {
    // device_info_plus 10+ no longer exposes displayMetrics; tablet detection
    // falls back to the Flutter MediaQuery breakpoint in Layout.isTablet().
    return 0;
  }

  Map<String, String> get headers => <String, String>{
        'X-Install-Id': installId,
        'X-App-Version': appVersion,
        'X-OS-Version': osVersion,
        'X-Device-Type': deviceType,
        'X-Platform': platform,
        'X-Session-Id': sessionId,
      };
}
