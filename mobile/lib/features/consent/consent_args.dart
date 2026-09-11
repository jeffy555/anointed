import '../../models/consent_status.dart';
import '../../services/oauth_provider_service.dart';

/// Passed from M-06A → M-06B after parent OAuth succeeds.
class AttestationArgs {
  const AttestationArgs({this.parentCredential});

  final OAuthCredential? parentCredential;
}

/// Passed from M-06B → M-06C with attestation fields filled.
class ChildProfileArgs {
  const ChildProfileArgs({
    required this.parentCredential,
    required this.parentGuardianName,
    required this.relationship,
    required this.isParentOrGuardian,
    required this.consentsToDataUse,
  });

  final OAuthCredential parentCredential;
  final String parentGuardianName;
  final ParentRelationship relationship;
  final bool isParentOrGuardian;
  final bool consentsToDataUse;
}

/// Passed from M-06D → M-06E after the email is sent.
class AwaitingEmailArgs {
  const AwaitingEmailArgs({required this.parentEmail});

  final String parentEmail;
}
