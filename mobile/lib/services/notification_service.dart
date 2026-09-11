import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/config.dart';
import '../core/local_store.dart';
import 'analytics_service.dart';

/// Local inactivity reminders (design-spec §22).
///
/// On-device only — there is no FCM/APNs server in v1, and no notification data
/// ever leaves the device. Default is off: no permission prompt at cold launch;
/// the prompt appears in-context after the first level completion (M-14) or from
/// the Settings toggle (M-27).
class NotificationService extends ChangeNotifier {
  NotificationService({
    required LocalStore store,
    required AnalyticsService analytics,
    FlutterLocalNotificationsPlugin? plugin,
  })  : _store = store,
        _analytics = analytics,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _idInactive3d = 3001;
  static const int _idInactive7d = 3002;
  static const String _channelId = 'anointed_play_reminders';

  final LocalStore _store;
  final AnalyticsService _analytics;
  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _timezoneReady = false;

  /// Set when the app was launched by tapping a reminder, so the analytics event
  /// can be attributed once the first real screen is known.
  String? _pendingLaunchTrigger;

  String? consumeLaunchTrigger() {
    final String? trigger = _pendingLaunchTrigger;
    _pendingLaunchTrigger = null;
    return trigger;
  }

  bool get optedIn => _store.notificationsOptIn;
  bool get promptAlreadyShown => _store.notifyPromptShown;

  bool _permissionBlocked = false;

  /// True once the OS has declined a permission request in this session. Neither
  /// iOS nor Android 13+ will show the system prompt a second time, so M-27 has
  /// to send the user to system settings instead of asking again.
  bool get permissionBlocked => _permissionBlocked;

  /// Initialises the plugin without requesting any permission. Permission is
  /// requested only when the user says yes (design-spec §22 rule 1).
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );

      // A cold launch from a tapped reminder is reported here rather than through
      // the tap callback, which does not fire for a terminated app.
      final NotificationAppLaunchDetails? details =
          await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        _pendingLaunchTrigger = _triggerForId(details?.notificationResponse?.id);
      }

      _ready = true;
    } on Object catch (error) {
      // Notifications are a retention nicety; a plugin failure must not break
      // launch. optedIn stays whatever it was and scheduling silently no-ops.
      if (kDebugMode) debugPrint('notification init failed: $error');
    }
  }

  void _onTap(NotificationResponse response) {
    final String trigger = _triggerForId(response.id) ?? 'unknown';
    _analytics.track('local_notification_opened', properties: <String, Object?>{
      'trigger': trigger,
      'entry_screen': 'M-11_level_map',
    });
  }

  String? _triggerForId(int? id) {
    switch (id) {
      case _idInactive3d:
        return 'inactive_3d';
      case _idInactive7d:
        return 'inactive_7d';
      default:
        return null;
    }
  }

  /// Asks the OS for permission. Returns false if the user or the OS declined —
  /// M-27 then links out to the system settings rather than asking again.
  Future<bool> requestPermission() async {
    await init();
    try {
      if (Platform.isIOS) {
        final bool? granted = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return _recordPermission(granted ?? false);
      }
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // Android 12 and earlier have no runtime notification permission, so a null
      // answer there means "already allowed", not "denied".
      final bool? granted = await android?.requestNotificationsPermission();
      return _recordPermission(granted ?? true);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('notification permission request failed: $error');
      return _recordPermission(false);
    }
  }

  bool _recordPermission(bool granted) {
    if (_permissionBlocked != !granted) {
      _permissionBlocked = !granted;
      notifyListeners();
    }
    return granted;
  }

  /// design-spec §22: cancel and reschedule on every app open, so the reminder
  /// always counts from the most recent session rather than from install.
  Future<void> rescheduleForActiveSession({
    required int currentLevel,
    required String reminder3dTitle,
    required String reminder3dBody,
    required String reminder7dTitle,
    required String reminder7dBody,
    required String channelName,
    required String channelDescription,
  }) async {
    await cancelAll();
    if (!optedIn) return;

    await init();
    if (!_ready) return;
    await _ensureTimezone();

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final bool scheduled3d = await _schedule(
      id: _idInactive3d,
      title: reminder3dTitle,
      body: reminder3dBody,
      after: AppConfig.inactivityNudge1,
      details: details,
    );
    final bool scheduled7d = await _schedule(
      id: _idInactive7d,
      title: reminder7dTitle,
      body: reminder7dBody,
      after: AppConfig.inactivityNudge2,
      details: details,
    );

    if (scheduled3d) {
      _analytics.track('local_notification_scheduled', properties: <String, Object?>{
        'trigger': 'inactive_3d',
        'current_level': currentLevel,
      });
    }
    if (scheduled7d) {
      _analytics.track('local_notification_scheduled', properties: <String, Object?>{
        'trigger': 'inactive_7d',
        'current_level': currentLevel,
      });
    }
  }

  Future<bool> _schedule({
    required int id,
    required String title,
    required String body,
    required Duration after,
    required NotificationDetails details,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(after),
        details,
        // Inexact is deliberate: an exact alarm needs a special Android
        // permission that a re-engagement nudge does not justify asking for.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } on Object catch (error) {
      if (kDebugMode) debugPrint('schedule $id failed: $error');
      return false;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancel(_idInactive3d);
      await _plugin.cancel(_idInactive7d);
    } on Object {
      // Nothing scheduled, or the plugin is unavailable on this platform.
    }
  }

  Future<void> setOptIn(bool value) async {
    await _store.setNotificationsOptIn(value);
    if (!value) {
      await cancelAll();
    } else {
      _permissionBlocked = false;
    }
    notifyListeners();
  }

  Future<void> markPromptShown() => _store.setNotifyPromptShown(true);

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    try {
      tz_data.initializeTimeZones();
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _timezoneReady = true;
    } on Object catch (error) {
      // Fall back to UTC. A reminder that fires a few hours off is better than
      // no reminder, and the offset only matters for absolute-time scheduling.
      if (kDebugMode) debugPrint('timezone setup failed, using UTC: $error');
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('UTC'));
        _timezoneReady = true;
      } on Object {
        _timezoneReady = false;
      }
    }
  }
}
