import '../core/api_client.dart';
import '../core/local_store.dart';
import '../models/account.dart';

/// `/v1/account/*` — profile, settings, deletion, and support (M-26–M-31).
class AccountRepository {
  AccountRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// M-26. Caches so design-spec §15's "show cached profile + refresh failed
  /// toast" state has something to show.
  Future<UserProfile> profile() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/account/profile');
    final UserProfile profile = UserProfile.fromJson(json);
    await _store.setCachedProfile(profile.toJson());
    return profile;
  }

  UserProfile? cachedProfile() {
    final Map<String, dynamic>? json = _store.cachedProfile;
    if (json == null) return null;
    return UserProfile.fromJson(json);
  }

  /// M-27. Only the notification opt-in is server-side: text size and dark mode
  /// stay on-device because they never need to follow the account.
  Future<UserProfile> updateNotificationsOptIn(bool optIn) async {
    final Map<String, dynamic> json = await _api.patchJson(
      '/v1/account/settings',
      body: <String, Object?>{'notifications_opt_in': optIn},
    );
    final UserProfile profile = UserProfile.fromJson(json);
    await _store.setCachedProfile(profile.toJson());
    return profile;
  }

  /// M-29a/M-29b disclosure.
  Future<DeletionPreview> deletionPreview() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/account/deletion-preview');
    return DeletionPreview.fromJson(json);
  }

  /// M-29c. Both flags are required by the backend so a single stray request
  /// cannot destroy an account.
  Future<DeletionResult> deleteAccount() async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/account/delete',
      body: <String, Object?>{'confirm': true, 'acknowledged_permanent': true},
    );
    return DeletionResult.fromJson(json);
  }

  /// M-31 FAQ.
  Future<FaqBundle> faq() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/account/faq');
    return FaqBundle.fromJson(json);
  }

  /// M-31 contact form. The backend persists the request before attempting
  /// delivery, so a send that reports success has been recorded either way.
  Future<String> submitSupportRequest({
    required String subjectCategory,
    required String message,
    String? replyTo,
    String? entrySource,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/account/support',
      body: <String, Object?>{
        'subject_category': subjectCategory,
        'message': message,
        if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
        if (entrySource != null) 'entry_source': entrySource,
      },
    );
    return '${json['message'] ?? ''}';
  }
}
