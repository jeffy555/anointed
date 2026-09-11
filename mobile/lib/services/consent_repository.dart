import '../core/api_client.dart';
import '../models/consent_status.dart';
import '../models/session.dart';
import 'oauth_provider_service.dart';

/// `/v1/consent/*` — verifiable parental consent (design-spec §11).
class ConsentRepository {
  ConsentRepository(this._api);

  final ApiClient _api;

  /// Polled by M-06E every 5 seconds while a parent completes Path B.
  Future<ConsentStatus> status() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/consent/status');
    return ConsentStatus.fromJson(json);
  }

  /// Path A: M-06A parent OAuth + M-06B attestation + M-06C child profile, all
  /// submitted together so the consent record is written atomically.
  Future<SessionState> completeParentOAuth({
    required OAuthCredential parentCredential,
    required String parentGuardianName,
    required ParentRelationship relationship,
    required bool isParentOrGuardian,
    required bool consentsToDataUse,
    String? childDisplayName,
    String? childMobile,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/consent/parent-oauth/complete',
      body: <String, Object?>{
        'parent_provider': parentCredential.provider.wireValue,
        'parent_id_token': parentCredential.idToken,
        'parent_guardian_name': parentGuardianName,
        'parent_relationship': relationship.wireValue,
        'is_parent_or_guardian': isParentOrGuardian,
        'consents_to_data_use': consentsToDataUse,
        if (childDisplayName != null && childDisplayName.isNotEmpty)
          'child_display_name': childDisplayName,
        if (childMobile != null && childMobile.isNotEmpty) 'child_mobile': childMobile,
      },
    );
    return SessionState.fromJson(json);
  }

  /// Path B: M-06D. Sends the signed 72h link to the parent's own email address.
  Future<ConsentStatus> requestParentEmail(String parentEmail) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/consent/email/request',
      body: <String, Object?>{'parent_email': parentEmail},
    );
    return ConsentStatus.fromJson(json);
  }

  /// M-07, shown only after VPC is verified either way.
  Future<SessionState> acknowledgeChildNotice({
    String acknowledgedBy = 'parent',
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/consent/child-notice/acknowledge',
      body: <String, Object?>{'acknowledged_by': acknowledgedBy},
    );
    return SessionState.fromJson(json);
  }
}
