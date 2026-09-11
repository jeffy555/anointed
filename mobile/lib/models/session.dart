/// Onboarding routing decided by the server (`next_step` in the auth responses).
///
/// design-spec §3 keeps the age-gate/VPC routing rules in exactly one place —
/// the backend — so a client cannot skip the VPC flow by not navigating to it.
/// This enum is the client-side mirror of `app.services.accounts.STEP_*`.
enum OnboardingStep {
  profileCompletion('profile_completion'),
  parentalConsent('parental_consent'),
  childPrivacyNotice('child_privacy_notice'),
  privacyAcknowledgment('privacy_acknowledgment'),
  levelMap('level_map');

  const OnboardingStep(this.wireValue);

  final String wireValue;

  static OnboardingStep parse(Object? value) {
    for (final OnboardingStep step in OnboardingStep.values) {
      if (step.wireValue == value) return step;
    }
    // An unrecognised step means the server is ahead of this build. Sending the
    // user to the level map would skip an onboarding requirement, so treat the
    // safest reachable gate — privacy acknowledgment — as the fallback.
    return OnboardingStep.privacyAcknowledgment;
  }
}

enum AccountStatus {
  pendingParentalConsent('pending_parental_consent'),
  consented('consented'),
  consentExpired('consent_expired'),
  consentDenied('consent_denied'),
  abandonedPendingCleanup('abandoned_pending_cleanup'),
  deleted('deleted');

  const AccountStatus(this.wireValue);

  final String wireValue;

  static AccountStatus parse(Object? value) {
    for (final AccountStatus status in AccountStatus.values) {
      if (status.wireValue == value) return status;
    }
    return AccountStatus.pendingParentalConsent;
  }

  bool get blocksGameplay => this != AccountStatus.consented;
}

enum AgeGroup {
  kid('kid'),
  youth('youth'),
  adult('adult'),
  elder('elder');

  const AgeGroup(this.wireValue);

  final String wireValue;

  static AgeGroup? parse(Object? value) {
    if (value == null) return null;
    for (final AgeGroup group in AgeGroup.values) {
      if (group.wireValue == value) return group;
    }
    return null;
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.age,
    required this.ageGroup,
    required this.isUnder13,
    required this.accountStatus,
    required this.primaryAuthProvider,
    required this.privacyAccepted,
    required this.childNoticeAcknowledged,
    required this.notificationsOptIn,
    required this.hasUnlock,
    required this.highestLevelCompleted,
    required this.levelsCompletedCount,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: '${json['id']}',
        name: json['name'] as String?,
        age: json['age'] as int?,
        ageGroup: AgeGroup.parse(json['age_group']),
        isUnder13: json['is_under_13'] == true,
        accountStatus: AccountStatus.parse(json['account_status']),
        primaryAuthProvider: json['primary_auth_provider'] as String?,
        privacyAccepted: json['privacy_accepted'] == true,
        childNoticeAcknowledged: json['child_notice_acknowledged'] == true,
        notificationsOptIn: json['notifications_opt_in'] == true,
        hasUnlock: json['has_unlock'] == true,
        highestLevelCompleted: (json['highest_level_completed'] as num?)?.toInt() ?? 0,
        levelsCompletedCount: (json['levels_completed_count'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String? name;
  final int? age;
  final AgeGroup? ageGroup;
  final bool isUnder13;
  final AccountStatus accountStatus;
  final String? primaryAuthProvider;
  final bool privacyAccepted;
  final bool childNoticeAcknowledged;
  final bool notificationsOptIn;
  final bool hasUnlock;
  final int highestLevelCompleted;
  final int levelsCompletedCount;

  /// design-spec §20 / analytics-spec §15: under-13 accounts are ad-free and the
  /// ad SDK is never initialised for them. Checked client-side as well as
  /// server-side because the SDK must not even load.
  bool get adsPermitted => !isUnder13 && accountStatus == AccountStatus.consented;

  bool get canPlay => accountStatus == AccountStatus.consented;

  int get currentLevel => highestLevelCompleted + 1;

  SessionUser copyWith({
    String? name,
    bool? notificationsOptIn,
    bool? hasUnlock,
    int? highestLevelCompleted,
    int? levelsCompletedCount,
  }) {
    return SessionUser(
      id: id,
      name: name ?? this.name,
      age: age,
      ageGroup: ageGroup,
      isUnder13: isUnder13,
      accountStatus: accountStatus,
      primaryAuthProvider: primaryAuthProvider,
      privacyAccepted: privacyAccepted,
      childNoticeAcknowledged: childNoticeAcknowledged,
      notificationsOptIn: notificationsOptIn ?? this.notificationsOptIn,
      hasUnlock: hasUnlock ?? this.hasUnlock,
      highestLevelCompleted: highestLevelCompleted ?? this.highestLevelCompleted,
      levelsCompletedCount: levelsCompletedCount ?? this.levelsCompletedCount,
    );
  }
}

/// Response from the sign-up / sign-in endpoints, which also mint the session.
class AuthResult {
  const AuthResult({
    required this.sessionToken,
    required this.user,
    required this.nextStep,
    required this.isNewAccount,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        sessionToken: '${json['session_token']}',
        user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
        nextStep: OnboardingStep.parse(json['next_step']),
        isNewAccount: json['is_new_account'] == true,
      );

  final String sessionToken;
  final SessionUser user;
  final OnboardingStep nextStep;
  final bool isNewAccount;
}

/// Response from endpoints that update an existing session without reissuing a
/// token (privacy accept, consent complete, child notice ack, GET /session).
class SessionState {
  const SessionState({required this.user, required this.nextStep});

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
        user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
        nextStep: OnboardingStep.parse(json['next_step']),
      );

  final SessionUser user;
  final OnboardingStep nextStep;
}
