import '../models/level.dart';

/// Named routes.
///
/// Navigator 1.0 with named routes rather than go_router: v1 has no deep links
/// (`backend.deepLinking = "not required"`), so declarative URL routing would add
/// a dependency without buying anything. Noted as an assumption in
/// mobile/README.md.
class Routes {
  const Routes._();

  static const String splash = '/';
  static const String forceUpgrade = '/force-upgrade';
  static const String welcome = '/welcome';
  static const String phoneSignUp = '/phone-sign-up';
  static const String signIn = '/sign-in';
  static const String profileCompletion = '/profile-completion';

  static const String parentGate = '/consent/gate';
  static const String parentOauth = '/consent/parent-oauth';
  static const String parentAttestation = '/consent/attestation';
  static const String childProfile = '/consent/child-profile';
  static const String parentEmail = '/consent/parent-email';
  static const String awaitingEmail = '/consent/awaiting-email';
  static const String childNotice = '/child-notice';
  static const String privacyTerms = '/privacy-terms';

  static const String home = '/home';
  static const String gameplay = '/gameplay';
  static const String levelComplete = '/level-complete';
  static const String levelFail = '/level-fail';
  static const String timerExpired = '/timer-expired';
  static const String adBreak = '/ad-break';

  static const String iapUnlock = '/iap/unlock';
  static const String purchaseSuccess = '/iap/success';
  static const String purchaseFailed = '/iap/failed';
  static const String restorePurchase = '/iap/restore';

  static const String practiceGameplay = '/practice/gameplay';
  static const String practiceResult = '/practice/result';

  static const String kidsZone = '/kids-zone';
  static const String kidsZoneGameplay = '/kids-zone/gameplay';
  static const String kidsZoneComplete = '/kids-zone/complete';

  static const String settings = '/settings';
  static const String accountDeletion = '/account-deletion';
  static const String support = '/support';
}

/// Which bottom-nav/rail destination [Routes.home] should open on.
enum HomeTab { map, leaderboard, practice, profile }

class HomeArgs {
  const HomeArgs({this.tab = HomeTab.map, this.showSyncFailedToast = false});

  final HomeTab tab;
  final bool showSyncFailedToast;
}

class GameplayArgs {
  const GameplayArgs({required this.level});

  final LevelDetail level;
}

class LevelCompleteArgs {
  const LevelCompleteArgs({
    required this.levelNumber,
    required this.score,
    required this.attemptNumber,
    required this.userRank,
    required this.nextLevelNumber,
    required this.nextLevelLocked,
    required this.adEligible,
    required this.scoreSyncDeferred,
  });

  final int levelNumber;
  final int? score;
  final int attemptNumber;
  final int? userRank;
  final int? nextLevelNumber;
  final bool nextLevelLocked;
  final bool adEligible;

  /// design-spec §6 Flow 5: a completion that could not reach the server shows
  /// "Score saved — will sync when online" instead of a rank.
  final bool scoreSyncDeferred;
}

enum FailReason { wrongAnswer, timerExpired }

class LevelFailArgs {
  const LevelFailArgs({
    required this.level,
    required this.reason,
    required this.attemptNumber,
    required this.questionIndexAtFail,
  });

  final LevelDetail level;
  final FailReason reason;
  final int attemptNumber;
  final int questionIndexAtFail;

  String get analyticsReason =>
      reason == FailReason.timerExpired ? 'timer_expired' : 'wrong_answer';
}

class AdBreakArgs {
  const AdBreakArgs({required this.levelNumber, required this.next});

  final int levelNumber;

  /// Where to go once the ad is dismissed or skipped.
  final AdBreakDestination next;
}

enum AdBreakDestination { levelMap, iapPrompt }

/// Where the M-22 prompt was reached from — analytics-spec §7 `trigger`.
enum IapTrigger {
  levelFiveComplete('level_5_complete'),
  lockedLevelTap('locked_level_tap');

  const IapTrigger(this.wireValue);

  final String wireValue;
}

class IapArgs {
  const IapArgs({required this.trigger, this.returnToLevel});

  final IapTrigger trigger;

  /// Level to open once the unlock succeeds, when the prompt came from a locked
  /// node tap.
  final int? returnToLevel;
}

class PurchaseFailedArgs {
  const PurchaseFailedArgs({required this.trigger, this.errorCode});

  final IapTrigger trigger;
  final String? errorCode;
}

class PracticeGameplayArgs {
  const PracticeGameplayArgs({required this.levelNumber, this.attemptNumber = 1});

  final int levelNumber;
  final int attemptNumber;
}

class PracticeResultArgs {
  const PracticeResultArgs({
    required this.levelNumber,
    required this.passed,
    required this.correctCount,
    required this.totalCount,
    required this.attemptNumber,
    required this.failReason,
    required this.questionIndexAtFail,
    required this.elapsedMs,
    required this.levelUnlockedInMainMode,
  });

  final int levelNumber;
  final bool passed;
  final int correctCount;
  final int totalCount;
  final int attemptNumber;
  final FailReason? failReason;
  final int questionIndexAtFail;
  final int elapsedMs;

  /// Drives the "Play this level for real" CTA, which design-spec §1G wants on
  /// M-20 to steer players back to ranked mode.
  final bool levelUnlockedInMainMode;
}

class AccountDeletionArgs {
  const AccountDeletionArgs();
}

class KidsZoneGameplayArgs {
  const KidsZoneGameplayArgs({
    required this.adventureId,
    required this.stopId,
    required this.stopTitle,
    required this.adventureTitle,
  });

  final String adventureId;
  final String stopId;
  final String stopTitle;
  final String adventureTitle;
}

class KidsZoneCompleteArgs {
  const KidsZoneCompleteArgs({
    required this.adventureId,
    required this.stopId,
    required this.stopTitle,
    required this.stars,
    required this.nextStopId,
  });

  final String adventureId;
  final String stopId;
  final String stopTitle;
  final int stars;
  final String? nextStopId;
}

class SupportArgs {
  const SupportArgs({this.entrySource = 'M-26_profile', this.presetCategory});

  /// analytics-spec §10 `entry_source` — design-spec §14 links here from M-24
  /// purchase errors and M-10 sign-in failures as well as the profile tab.
  final String entrySource;
  final String? presetCategory;
}
