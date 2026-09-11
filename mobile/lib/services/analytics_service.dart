import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/connectivity.dart';
import '../core/local_store.dart';
import '../models/session.dart';

/// Batched client-side analytics (analytics-spec §15).
///
/// Events queue in memory, persist to disk so an app kill doesn't lose them, and
/// flush to `POST /v1/analytics/events` on a timer, on batch size, and whenever
/// connectivity returns. Offline practice sessions therefore still report.
///
/// The backend emits the events it already owns (level_started, level_completed,
/// purchase_completed, …) from inside the corresponding request, so this service
/// only sends the events that have no server-side trigger. Sending both would
/// double-count every funnel.
class AnalyticsService {
  AnalyticsService({
    required ApiClient api,
    required LocalStore store,
    required ConnectivityService connectivity,
  })  : _api = api,
        _store = store,
        _connectivity = connectivity {
    _queue.addAll(_store.analyticsQueue);
    _connectivity.addReconnectListener(() => flush());
    _timer = Timer.periodic(AppConfig.analyticsFlushInterval, (_) => flush());
  }

  final ApiClient _api;
  final LocalStore _store;
  final ConnectivityService _connectivity;

  final List<String> _queue = <String>[];
  Timer? _timer;
  bool _flushing = false;

  /// Kept in sync by the session controller so the under-13 gate below can be
  /// applied without every call site having to pass the account state.
  AccountStatus? _accountStatus;

  void setAccountStatus(AccountStatus? status) => _accountStatus = status;

  /// Events a `pending_parental_consent` account may still emit.
  ///
  /// analytics-spec §15: such an account emits only VPC/onboarding events plus
  /// `screen_view` for VPC screens — no gameplay, ad, purchase, or leaderboard
  /// events until consent is verified. Enforced here rather than at each call
  /// site so a new call site cannot accidentally leak a child's gameplay event.
  static const Set<String> _pendingConsentAllowList = <String>{
    'screen_view',
    'session_start',
    'force_upgrade_shown',
    'sign_up_started',
    'sign_up_completed',
    'sign_in_completed',
    'sign_out_completed',
    'age_gate_triggered',
    'vpc_parent_gate_viewed',
    'vpc_path_selected',
    'vpc_parent_oauth_completed',
    'vpc_attestation_submitted',
    'vpc_email_requested',
    'vpc_email_verified',
    'vpc_consent_denied',
    'parental_consent_completed',
    'child_privacy_notice_acknowledged',
    'account_deletion_started',
    'account_deleted',
    'support_faq_viewed',
    'support_contact_sent',
    'content_manifest_checked',
    'content_cache_updated',
    'content_cache_update_failed',
  };

  bool _isPermitted(String eventName) {
    if (_accountStatus != AccountStatus.pendingParentalConsent) return true;
    return _pendingConsentAllowList.contains(eventName);
  }

  /// Queues one event. [properties] must never contain PII — analytics-spec §2
  /// requires an opaque user id and nothing else identifying.
  void track(String eventName, {Map<String, Object?> properties = const <String, Object?>{}}) {
    if (!_isPermitted(eventName)) return;

    final Map<String, Object?> cleaned = <String, Object?>{};
    properties.forEach((String key, Object? value) {
      if (value != null) cleaned[key] = value;
    });

    _queue.add(jsonEncode(<String, Object?>{
      'event_name': eventName,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'properties': cleaned,
    }));

    // Drop the oldest events rather than growing without bound if a device stays
    // offline for a very long time.
    while (_queue.length > AppConfig.analyticsQueueCap) {
      _queue.removeAt(0);
    }
    _persist();

    if (_queue.length >= AppConfig.analyticsBatchSize) {
      flush();
    }
  }

  /// analytics-spec §3: fired on every screen transition by the route observer.
  void trackScreenView({
    required String screenName,
    String? previousScreen,
    int timeOnPreviousScreenMs = 0,
  }) {
    track('screen_view', properties: <String, Object?>{
      'screen_name': screenName,
      'previous_screen': previousScreen,
      'time_on_previous_screen_ms': timeOnPreviousScreenMs,
    });
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    if (!_connectivity.isOnline) return;

    _flushing = true;
    // Take at most one batch; the ingestion endpoint caps a request at 100 events.
    final int take = _queue.length > 100 ? 100 : _queue.length;
    final List<String> batch = _queue.sublist(0, take);

    try {
      final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
      for (final String raw in batch) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) events.add(decoded);
      }
      if (events.isEmpty) {
        _queue.removeRange(0, take);
        await _persist();
        return;
      }

      await _api.postJson('/v1/analytics/events', body: <String, Object?>{
        'events': events,
      });
      _queue.removeRange(0, take);
      await _persist();
    } on ApiException catch (error) {
      // 4xx other than auth means the batch will never be accepted, so keeping it
      // would block every later event behind a poison payload.
      final bool permanent = error.statusCode >= 400 &&
          error.statusCode < 500 &&
          !error.isUnauthorized;
      if (permanent) {
        _queue.removeRange(0, take);
        await _persist();
      }
      if (kDebugMode) {
        debugPrint('analytics flush failed: ${error.code}');
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _persist() => _store.setAnalyticsQueue(List<String>.of(_queue));

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
