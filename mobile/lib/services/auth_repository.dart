import '../core/api_client.dart';
import '../models/session.dart';
import 'oauth_provider_service.dart';

/// `/v1/auth/*` — Google, Apple, and phone (no SMS OTP in v1).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// One endpoint serves both M-03 sign-up and M-10 sign-in: an OAuth sign-in on
  /// a new device restores the existing account automatically (design-spec §9).
  Future<AuthResult> signInWithOAuth(
    OAuthCredential credential, {
    int? age,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/auth/oauth',
      body: <String, Object?>{
        'provider': credential.provider.wireValue,
        'id_token': credential.idToken,
        if (credential.name != null) 'name': credential.name,
        if (age != null) 'age': age,
      },
    );
    return AuthResult.fromJson(json);
  }

  /// M-04. Rate-limited server-side by install id and IP (design-spec §21).
  Future<AuthResult> phoneSignUp({
    required String mobile,
    required String name,
    required int age,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/auth/phone/signup',
      body: <String, Object?>{'mobile': mobile, 'name': name, 'age': age},
    );
    return AuthResult.fromJson(json);
  }

  /// M-10 phone path: mobile + name match, no OTP.
  Future<AuthResult> phoneSignIn({
    required String mobile,
    required String name,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/auth/phone/signin',
      body: <String, Object?>{'mobile': mobile, 'name': name},
    );
    return AuthResult.fromJson(json);
  }

  /// Age capture for the OAuth path, where the provider never supplies age.
  /// The response's `next_step` is the M-05 age-gate decision.
  Future<AuthResult> completeProfile({
    required String name,
    required int age,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/auth/profile',
      body: <String, Object?>{'name': name, 'age': age},
    );
    return AuthResult.fromJson(json);
  }

  /// M-08 — "Continue" is acceptance.
  Future<SessionState> acceptPrivacy() async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/auth/privacy-accept',
      body: <String, Object?>{'accepted': true},
    );
    return SessionState.fromJson(json);
  }

  /// M-01 session routing. Also records `session_start` server-side for DAU.
  Future<SessionState> currentSession() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/auth/session');
    return SessionState.fromJson(json);
  }

  /// M-30. Sessions are stateless JWTs, so the client discards its token; this
  /// call exists so the intentional session end is recorded.
  Future<void> signOut() async {
    await _api.postJson('/v1/auth/signout');
  }
}
