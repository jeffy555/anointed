import 'session.dart';

/// VPC method identifiers from design-spec §11. Also the `vpc_path` analytics
/// property value.
enum ConsentMethod {
  oauthParentAttestation('oauth_parent_attestation'),
  emailPlusConfirmation('email_plus_confirmation');

  const ConsentMethod(this.wireValue);

  final String wireValue;

  static ConsentMethod? parse(Object? value) {
    if (value == null) return null;
    for (final ConsentMethod method in ConsentMethod.values) {
      if (method.wireValue == value) return method;
    }
    return null;
  }
}

enum ParentRelationship {
  parent('parent'),
  guardian('guardian'),
  other('other');

  const ParentRelationship(this.wireValue);

  final String wireValue;
}

enum ConsentRecordStatus {
  pending('pending'),
  verified('verified'),
  expired('expired'),
  denied('denied');

  const ConsentRecordStatus(this.wireValue);

  final String wireValue;

  static ConsentRecordStatus? parse(Object? value) {
    if (value == null) return null;
    for (final ConsentRecordStatus status in ConsentRecordStatus.values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

/// `GET /v1/consent/status` — polled by M-06E every 5 seconds.
class ConsentStatus {
  const ConsentStatus({
    required this.accountStatus,
    required this.consentStatus,
    required this.method,
    required this.parentEmailMasked,
    required this.expiresAt,
    required this.canResendAt,
    required this.sendCount,
    required this.nextStep,
  });

  factory ConsentStatus.fromJson(Map<String, dynamic> json) => ConsentStatus(
        accountStatus: AccountStatus.parse(json['account_status']),
        consentStatus: ConsentRecordStatus.parse(json['consent_status']),
        method: ConsentMethod.parse(json['method']),
        parentEmailMasked: json['parent_email_masked'] as String?,
        expiresAt: _date(json['expires_at']),
        canResendAt: _date(json['can_resend_at']),
        sendCount: (json['send_count'] as num?)?.toInt() ?? 0,
        nextStep: OnboardingStep.parse(json['next_step']),
      );

  final AccountStatus accountStatus;
  final ConsentRecordStatus? consentStatus;
  final ConsentMethod? method;
  final String? parentEmailMasked;
  final DateTime? expiresAt;
  final DateTime? canResendAt;
  final int sendCount;
  final OnboardingStep nextStep;

  bool get isVerified => accountStatus == AccountStatus.consented;

  /// Seconds until "Resend email" becomes available again (60s cooldown, §11).
  int get resendCooldownSeconds {
    final DateTime? at = canResendAt;
    if (at == null) return 0;
    final int seconds = at.difference(DateTime.now().toUtc()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
