/// Screen identifiers used for `screen_view` analytics.
///
/// analytics-spec §3 requires `screen_name` to match the design-spec screen IDs,
/// so these strings are part of the analytics contract, not display copy — they
/// are intentionally not localized.
class ScreenIds {
  const ScreenIds._();

  static const String splash = 'M-01_splash';
  static const String forceUpgrade = 'M-02_force_upgrade';
  static const String welcome = 'M-03_welcome';
  static const String phoneSignUp = 'M-04_phone_sign_up';
  static const String profileCompletion = 'M-03_profile_completion';
  static const String parentGate = 'M-06_parent_gate';
  static const String parentOauth = 'M-06A_parent_oauth';
  static const String parentAttestation = 'M-06B_parent_attestation';
  static const String childProfile = 'M-06C_child_profile';
  static const String parentEmail = 'M-06D_parent_email';
  static const String awaitingEmail = 'M-06E_awaiting_email';
  static const String childNotice = 'M-07_child_privacy_notice';
  static const String privacyTerms = 'M-08_privacy_terms';
  static const String signIn = 'M-10_sign_in';
  static const String levelMap = 'M-11_level_map';
  static const String levelDetail = 'M-12_level_detail';
  static const String gameplay = 'M-13_gameplay';
  static const String levelComplete = 'M-14_level_complete';
  static const String levelFail = 'M-15_level_fail';
  static const String timerExpired = 'M-16_timer_expired';
  static const String leaderboard = 'M-17_leaderboard';
  static const String practiceHub = 'M-18_practice_hub';
  static const String practiceGameplay = 'M-19_practice_gameplay';
  static const String practiceResult = 'M-20_practice_result';
  static const String adBreak = 'M-21_ad_break';
  static const String iapUnlock = 'M-22_iap_unlock';
  static const String purchaseSuccess = 'M-23_purchase_success';
  static const String purchaseFailed = 'M-24_purchase_failed';
  static const String restorePurchase = 'M-25_restore_purchase';
  static const String profile = 'M-26_profile';
  static const String settings = 'M-27_settings';
  static const String accountDeletion = 'M-29_account_deletion';
  static const String signOut = 'M-30_sign_out';
  static const String support = 'M-31_support';
  static const String kidsZoneHub = 'M-32_kids_zone_hub';
  static const String kidsZoneGameplay = 'M-33_kids_zone_gameplay';
  static const String kidsZoneComplete = 'M-34_kids_zone_complete';

  /// Screens a `pending_parental_consent` account is allowed to emit
  /// `screen_view` for (analytics-spec §15 under-13 data handling).
  static const Set<String> vpcScreens = <String>{
    parentGate,
    parentOauth,
    parentAttestation,
    childProfile,
    parentEmail,
    awaitingEmail,
    childNotice,
    privacyTerms,
    welcome,
    phoneSignUp,
    profileCompletion,
    signIn,
    splash,
    forceUpgrade,
    support,
    profile,
    settings,
    accountDeletion,
  };
}
