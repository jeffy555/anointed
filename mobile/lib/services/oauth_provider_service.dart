import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/config.dart';
import '../core/local_store.dart';

enum OAuthProviderKind {
  google('google'),
  apple('apple');

  const OAuthProviderKind(this.wireValue);

  final String wireValue;
}

/// Credential handed to `POST /v1/auth/oauth` or the VPC Path A endpoint.
class OAuthCredential {
  const OAuthCredential({
    required this.provider,
    required this.idToken,
    this.name,
    this.isDevToken = false,
  });

  final OAuthProviderKind provider;
  final String idToken;
  final String? name;
  final bool isDevToken;
}

class OAuthCancelled implements Exception {
  const OAuthCancelled();
}

class OAuthFailure implements Exception {
  const OAuthFailure(this.provider, [this.detail]);

  final OAuthProviderKind provider;
  final String? detail;

  @override
  String toString() => 'OAuthFailure(${provider.wireValue}): $detail';
}

/// Google Sign-In and Sign in with Apple (design-spec §10).
class OAuthProviderService {
  OAuthProviderService(this._store);

  final LocalStore _store;

  GoogleSignIn? _google;

  GoogleSignIn get _googleClient {
    return _google ??= GoogleSignIn(
      scopes: const <String>['email'],
      // Android identifies the app by package + signing SHA-1 — do not pass
      // clientId here (google_sign_in_android ignores it when serverClientId is set).
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
  }

  bool get appleAvailable => !kIsWeb && Platform.isIOS;

  Future<OAuthCredential> signIn(
    OAuthProviderKind provider, {
    bool forceAccountPicker = false,
    String? devNameHint,
  }) async {
    switch (provider) {
      case OAuthProviderKind.google:
        return _signInWithGoogle(
          forceAccountPicker: forceAccountPicker,
          devNameHint: devNameHint,
        );
      case OAuthProviderKind.apple:
        return _signInWithApple(devNameHint: devNameHint);
    }
  }

  Future<OAuthCredential> _signInWithGoogle({
    required bool forceAccountPicker,
    String? devNameHint,
  }) async {
    try {
      if (forceAccountPicker) {
        try {
          await _googleClient.disconnect();
        } on Object {
          await _googleClient.signOut();
        }
      }

      final GoogleSignInAccount? account = await _googleClient.signIn();
      if (account == null) throw const OAuthCancelled();

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (AppConfig.googleOAuthConfigured) {
          throw OAuthFailure(
            OAuthProviderKind.google,
            'Google did not return a sign-in token. Check OAuth client IDs, SHA-1, '
            'and package name com.anointed.anointed in Google Cloud Console.',
          );
        }
        return _devCredential(
          OAuthProviderKind.google,
          email: account.email,
          name: account.displayName ?? devNameHint,
          reason: 'no_id_token',
        );
      }

      return OAuthCredential(
        provider: OAuthProviderKind.google,
        idToken: idToken,
        name: account.displayName ?? devNameHint,
      );
    } on OAuthCancelled {
      rethrow;
    } on OAuthFailure {
      rethrow;
    } on PlatformException catch (error) {
      if (AppConfig.googleOAuthConfigured) {
        throw OAuthFailure(OAuthProviderKind.google, _googlePlatformMessage(error));
      }
      return _devCredential(
        OAuthProviderKind.google,
        name: devNameHint,
        reason: error.message ?? error.code,
      );
    } on Object catch (error) {
      if (AppConfig.googleOAuthConfigured) {
        throw OAuthFailure(OAuthProviderKind.google, '$error');
      }
      return _devCredential(
        OAuthProviderKind.google,
        name: devNameHint,
        reason: '$error',
      );
    }
  }

  Future<OAuthCredential> _signInWithApple({String? devNameHint}) async {
    if (!appleAvailable) {
      if (AppConfig.devOAuthFallback) {
        return _devCredential(
          OAuthProviderKind.apple,
          name: devNameHint,
          reason: 'apple_unavailable_on_platform',
        );
      }
      throw const OAuthFailure(
        OAuthProviderKind.apple,
        'Sign in with Apple is only available on iOS.',
      );
    }

    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? identityToken = credential.identityToken;
      final String? name = _joinName(credential.givenName, credential.familyName);

      if (identityToken == null || identityToken.isEmpty) {
        return _devCredential(
          OAuthProviderKind.apple,
          email: credential.email,
          name: name ?? devNameHint,
          reason: 'no_identity_token',
        );
      }

      return OAuthCredential(
        provider: OAuthProviderKind.apple,
        idToken: identityToken,
        name: name ?? devNameHint,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const OAuthCancelled();
      }
      if (AppConfig.devOAuthFallback) {
        return _devCredential(
          OAuthProviderKind.apple,
          name: devNameHint,
          reason: '${error.code}',
        );
      }
      throw OAuthFailure(OAuthProviderKind.apple, '${error.code}');
    } on Object catch (error) {
      if (AppConfig.devOAuthFallback) {
        return _devCredential(
          OAuthProviderKind.apple,
          name: devNameHint,
          reason: '$error',
        );
      }
      throw OAuthFailure(OAuthProviderKind.apple, '$error');
    }
  }

  OAuthCredential _devCredential(
    OAuthProviderKind provider, {
    String? email,
    String? name,
    required String reason,
  }) {
    if (!AppConfig.devOAuthFallback) {
      throw OAuthFailure(provider, reason);
    }
    if (kDebugMode) {
      debugPrint(
        '[oauth] ${provider.wireValue} dev fallback ($reason). '
        'Configure real OAuth client IDs to disable this path.',
      );
    }

    final String subject = _store.devOAuthSubject(provider.wireValue);
    final String resolvedEmail = email ?? '$subject@dev.local';
    final String resolvedName = (name == null || name.trim().isEmpty) ? '' : name.trim();

    return OAuthCredential(
      provider: provider,
      idToken: 'devtoken:$subject:$resolvedEmail:$resolvedName',
      name: resolvedName.isEmpty ? null : resolvedName,
      isDevToken: true,
    );
  }

  OAuthCredential devParentCredential(
    OAuthProviderKind provider, {
    required String parentName,
  }) {
    final String subject = _store.devOAuthSubject('parent_${provider.wireValue}');
    return OAuthCredential(
      provider: provider,
      idToken: 'devtoken:$subject:$subject@parent.dev.local:$parentName',
      name: parentName,
      isDevToken: true,
    );
  }

  Future<void> signOutProviders() async {
    try {
      await _googleClient.signOut();
    } on Object {
      // Best effort.
    }
  }

  String? _joinName(String? given, String? family) {
    final String joined = <String?>[given, family]
        .where((String? part) => part != null && part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return joined.isEmpty ? null : joined;
  }

  String _googlePlatformMessage(PlatformException error) {
    final String raw = '${error.code} ${error.message ?? ''}';
    if (raw.contains('10') ||
        raw.contains('DEVELOPER_ERROR') ||
        raw.contains('sign_in_failed')) {
      return 'Google Sign-In setup error. In Google Cloud Console verify:\n'
          '1. OAuth consent screen is configured (Testing or Published)\n'
          '2. Your Gmail is added as a Test user (if status is Testing)\n'
          '3. Android OAuth client: package com.anointed.anointed\n'
          '4. SHA-1: 45:58:71:93:51:03:15:86:13:ED:D6:21:9C:66:53:47:6A:29:D9:ED';
    }
    return error.message ?? raw;
  }
}
