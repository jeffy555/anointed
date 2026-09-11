import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Anointed';

  @override
  String get appTagline => 'Discover the people of the Bible';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSave => 'Save';

  @override
  String get actionOk => 'OK';

  @override
  String get actionSend => 'Send';

  @override
  String get actionBackToMap => 'Back to map';

  @override
  String get actionContactSupport => 'Contact support';

  @override
  String get actionUpdateNow => 'Update Now';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get loadingLabel => 'Loading…';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericBody => 'Please try again in a moment.';

  @override
  String get errorOfflineTitle => 'No internet connection';

  @override
  String get errorOfflineBody => 'Connect to the internet and try again.';

  @override
  String get errorSessionExpired => 'Please sign in again to continue.';

  @override
  String errorLinkFailed(String url) {
    return 'Couldn\'t open $url on this device.';
  }

  @override
  String get offlineBadge => 'Offline';

  @override
  String get splashCheckingUpdates => 'Getting things ready…';

  @override
  String get splashConnectionError => 'Can\'t connect to check for updates.';

  @override
  String get forceUpgradeTitle => 'Update Required';

  @override
  String get forceUpgradeBody => 'A new version of Anointed is available. Please update to continue playing.';

  @override
  String get forceUpgradeReleaseNotesLabel => 'What\'s new';

  @override
  String get forceUpgradeStoreUnavailable => 'Couldn\'t open the store. Please update Anointed from your app store.';

  @override
  String get welcomeHeadline => 'Learn the people of the Bible';

  @override
  String get welcomeSubhead => '100 levels of Bible character challenges.';

  @override
  String get welcomeContinueWithGoogle => 'Continue with Google';

  @override
  String get welcomeContinueWithApple => 'Continue with Apple';

  @override
  String get welcomeContinueWithPhone => 'Continue with phone number';

  @override
  String get welcomeSaveProgressNote => 'Save your progress on any device';

  @override
  String get welcomeOrDivider => 'or';

  @override
  String get welcomeAlreadyHaveAccount => 'Already have an account?';

  @override
  String get welcomeSignInLink => 'Sign in';

  @override
  String welcomeOauthFailed(String provider) {
    return 'Couldn\'t sign in with $provider. Try again or use phone number.';
  }

  @override
  String get providerGoogle => 'Google';

  @override
  String get providerApple => 'Apple';

  @override
  String get providerPhone => 'phone number';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubhead => 'Sign in to pick up where you left off.';

  @override
  String get signInWithPhoneTitle => 'Sign in with your phone number';

  @override
  String get signInAccountNotFound => 'We couldn\'t find an account with that mobile number and name. Double-check both fields match what you used at sign-up.';

  @override
  String get signInCreateAccountLink => 'Create a new account';

  @override
  String get signInNeedHelp => 'Contact support for account recovery';

  @override
  String get signInPhoneRecoveryHint => 'Enter the same mobile number and display name you used when you created your account. Spelling must match exactly.';

  @override
  String get signInRecoveryTitle => 'Getting your progress back';

  @override
  String get signInRecoveryBody => 'If you originally signed up with Google or Apple, use that button above — your progress is tied to that account.\n\nFor phone accounts, both the number and name must match exactly. On a new device, enter the same details you used before.\n\nStill stuck? Contact support with your mobile number and the name on the account.';

  @override
  String get signInRecoveryPrevent => 'Tip: write down the name you chose at sign-up. Phone accounts do not use SMS codes — your number plus that exact name is how we find you.';

  @override
  String get phoneSignUpTitle => 'Create your account';

  @override
  String get phoneSignUpSubhead => 'No verification code needed.';

  @override
  String get fieldMobileLabel => 'Mobile number';

  @override
  String get fieldMobileHint => 'Numbers only';

  @override
  String get fieldNameLabel => 'Your name';

  @override
  String get fieldAgeLabel => 'Age';

  @override
  String get fieldMobileInvalid => 'Enter a valid mobile number.';

  @override
  String get fieldNameRequired => 'Enter a name.';

  @override
  String get fieldAgeInvalid => 'Enter an age between 4 and 120.';

  @override
  String get phoneSignUpAccountExists => 'An account already exists with that number and name. Try signing in instead.';

  @override
  String get phoneSignUpCreateAction => 'Create account';

  @override
  String get profileCompletionTitle => 'Tell us about you';

  @override
  String get profileCompletionSubhead => 'We ask for age so we can keep younger players safe.';

  @override
  String get parentGateTitle => 'Ask a parent or guardian to continue';

  @override
  String get parentGateBody => 'Because this player is under 13, a parent or guardian needs to give permission before the account can be used. A grown-up should take over from here.';

  @override
  String get parentGateNoSkipNote => 'This step can\'t be skipped.';

  @override
  String get parentGatePathATitle => 'Parent signs in (recommended)';

  @override
  String get parentGatePathABody => 'A parent signs in with their own Google or Apple account and gives permission.';

  @override
  String get parentGatePathBTitle => 'Parent email confirmation';

  @override
  String get parentGatePathBBody => 'We email a parent a secure link they open on their own device.';

  @override
  String get parentGateStatusExpired => 'The previous permission link expired. Please start again.';

  @override
  String get parentGateStatusDenied => 'A parent or guardian declined permission for this account.';

  @override
  String get parentOauthTitle => 'Parent, please sign in';

  @override
  String get parentOauthBody => 'Use your own Google or Apple account — not your child\'s. You\'ll be asked to choose an account.';

  @override
  String get parentOauthWithGoogle => 'Continue as parent with Google';

  @override
  String get parentOauthWithApple => 'Continue as parent with Apple';

  @override
  String get parentOauthSameAccountError => 'Please sign in with a parent or guardian\'s own account, not the child\'s.';

  @override
  String get attestationTitle => 'Parent permission';

  @override
  String get attestationGuardianNameLabel => 'Parent or guardian full name';

  @override
  String get attestationGuardianNameRequired => 'Enter the parent or guardian\'s full name.';

  @override
  String get attestationRelationshipLabel => 'Relationship to the child';

  @override
  String get relationshipParent => 'Parent';

  @override
  String get relationshipGuardian => 'Legal guardian';

  @override
  String get relationshipOther => 'Other legal guardian';

  @override
  String get attestationIsGuardianCheckbox => 'I am the parent or legal guardian of this child.';

  @override
  String get attestationConsentCheckbox => 'I consent to the collection and use of my child\'s information as described in the Privacy Policy.';

  @override
  String get attestationPrivacyLink => 'Read the Privacy Policy';

  @override
  String get attestationIncomplete => 'Both permission checkboxes must be ticked to continue.';

  @override
  String get childProfileTitle => 'Set up your child\'s profile';

  @override
  String get childProfileNameLabel => 'Child\'s display name';

  @override
  String get childProfileMobileLabel => 'Child\'s mobile number (optional)';

  @override
  String childProfileAgeReadOnly(int age) {
    return 'Age: $age';
  }

  @override
  String get childProfileSubmit => 'Give permission and continue';

  @override
  String get parentEmailTitle => 'Parent\'s email address';

  @override
  String get parentEmailBody => 'Enter a parent or guardian\'s email address — not the child\'s. We\'ll send a secure link that expires in 72 hours.';

  @override
  String get parentEmailLabel => 'Parent\'s email address';

  @override
  String get parentEmailInvalid => 'Enter a valid email address.';

  @override
  String get parentEmailSend => 'Send permission email';

  @override
  String get awaitingEmailTitle => 'Waiting for a parent';

  @override
  String awaitingEmailBody(String email) {
    return 'We sent a link to $email. A parent must tap the link to continue.';
  }

  @override
  String get awaitingEmailChecking => 'Checking for permission…';

  @override
  String get awaitingEmailResend => 'Resend email';

  @override
  String awaitingEmailResendIn(int seconds) {
    return 'Resend available in ${seconds}s';
  }

  @override
  String get awaitingEmailResendSent => 'Permission email sent again.';

  @override
  String get awaitingEmailSwitchToOauth => 'Use Google or Apple instead';

  @override
  String awaitingEmailExpiresAt(String date) {
    return 'This link expires $date.';
  }

  @override
  String get awaitingEmailResendLimit => 'We\'ve sent the maximum number of permission emails for today.';

  @override
  String get childNoticeTitle => 'What we collect';

  @override
  String get childNoticeIntro => 'Here\'s what Anointed keeps, in plain language.';

  @override
  String get childNoticeItemName => 'A display name, so we can greet the player and show them on the leaderboard as a first name and last initial.';

  @override
  String get childNoticeItemAge => 'Age, so we know which rules to follow for younger players.';

  @override
  String get childNoticeItemProgress => 'Levels completed and scores, so progress is saved.';

  @override
  String get childNoticeItemNoAds => 'Players under 13 never see ads.';

  @override
  String get childNoticeItemDelete => 'A parent can delete everything at any time from the Profile screen.';

  @override
  String get childNoticeAcknowledge => 'I understand';

  @override
  String get privacyTitle => 'Privacy and Terms';

  @override
  String get privacyBody => 'Tap Continue to accept the Privacy Policy and Terms of Service.';

  @override
  String get privacyPolicyLink => 'Privacy Policy';

  @override
  String get termsLink => 'Terms of Service';

  @override
  String get privacyLinkUnavailable => 'Couldn\'t open that page right now.';

  @override
  String get navMap => 'Map';

  @override
  String get navLeaderboard => 'Leaderboard';

  @override
  String get navPractice => 'Practice';

  @override
  String get navProfile => 'Profile';

  @override
  String get levelMapTitle => 'Level map';

  @override
  String levelMapProgress(int current, int total) {
    return 'Level $current of $total';
  }

  @override
  String get levelMapSyncFailed => 'Your progress couldn\'t sync. Playing with last saved data.';

  @override
  String levelNodeLabel(int number) {
    return 'Level $number';
  }

  @override
  String get levelNodeStateLocked => 'locked';

  @override
  String get levelNodeStateUnlocked => 'unlocked';

  @override
  String get levelNodeStateCompleted => 'completed';

  @override
  String levelNodeSemantics(int number, String state) {
    return 'Level $number — $state';
  }

  @override
  String levelMapUnlockBanner(int from, int to) {
    return 'Unlock levels $from–$to';
  }

  @override
  String get levelMapConsentPending => 'A parent or guardian needs to finish giving permission before you can play.';

  @override
  String get levelMapConsentPendingAction => 'Finish parent permission';

  @override
  String levelDetailTitle(int number) {
    return 'Level $number';
  }

  @override
  String get levelDetailDifficulty => 'Difficulty';

  @override
  String levelDetailTimer(int seconds) {
    return '${seconds}s per question';
  }

  @override
  String levelDetailQuestions(int count) {
    return '$count questions';
  }

  @override
  String get levelDetailQuestionMix => 'Question types';

  @override
  String levelDetailBestScore(int score) {
    return 'Best score: $score';
  }

  @override
  String get levelDetailPlay => 'Play';

  @override
  String get levelDetailNotPlayable => 'This level is still being prepared. Try another one.';

  @override
  String get levelDetailLockedByProgress => 'Finish the level before this one first.';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyExpert => 'Expert';

  @override
  String get variantTextQa => 'Question';

  @override
  String get variantVerseClue => 'Verse clue';

  @override
  String get variantImageClue => 'Picture clue';

  @override
  String gameplayProgress(int index, int total) {
    return 'Question $index of $total';
  }

  @override
  String get gameplayVersePrompt => 'Which character is this verse about?';

  @override
  String get gameplayImagePrompt => 'Who is this Bible character?';

  @override
  String get gameplayReadAloud => 'Read question aloud';

  @override
  String get gameplayReadAloudStop => 'Stop reading';

  @override
  String get gameplayReadAloudSemantics => 'Read the question aloud';

  @override
  String gameplayTimerSemantics(int seconds) {
    return '$seconds seconds remaining';
  }

  @override
  String get gameplayCorrect => 'Correct';

  @override
  String get gameplayWrong => 'Not this time';

  @override
  String get gameplayLoadFailed => 'Something went wrong loading this level.';

  @override
  String get gameplayConnectionLost => 'Connection lost — your score won\'t be submitted.';

  @override
  String get gameplayTooFast => 'Take a moment to read the question, then answer.';

  @override
  String get gameplayAnswerRejected => 'That answer didn\'t register. Please answer again.';

  @override
  String get gameplayQuitTitle => 'Leave this level?';

  @override
  String get gameplayQuitBody => 'Your progress in this level will be lost.';

  @override
  String get gameplayQuitConfirm => 'Leave level';

  @override
  String get gameplayPracticeBadge => 'Practice mode';

  @override
  String get levelCompleteTitle => 'Level complete!';

  @override
  String levelCompleteScore(int score) {
    return 'Score: $score';
  }

  @override
  String levelCompleteAttempts(int count) {
    return 'Attempts: $count';
  }

  @override
  String get levelCompleteNextLevel => 'Next level';

  @override
  String get levelCompleteScoreQueued => 'Score saved — will sync when online.';

  @override
  String get levelCompleteNotifyTitle => 'Want a reminder when it\'s time to play again?';

  @override
  String get levelCompleteNotifyBody => 'We\'ll send one gentle nudge if you haven\'t played in a few days.';

  @override
  String get levelCompleteNotifyYes => 'Yes, remind me';

  @override
  String get levelCompleteNotifyNo => 'Not now';

  @override
  String get levelCompleteNotifyDenied => 'Reminders are switched off for Anointed in your device settings. You can turn them on there.';

  @override
  String get levelFailTitle => 'Great try!';

  @override
  String get levelFailBody => 'Play again to find the answer!';

  @override
  String get levelFailAction => 'Try again';

  @override
  String get timerExpiredTitle => 'Time\'s up!';

  @override
  String get timerExpiredBody => 'Give it another go — you\'ll be quicker this time.';

  @override
  String get adBreakTitle => 'A quick word from our sponsor';

  @override
  String get adBreakSubtitle => 'Your next level is on the way.';

  @override
  String iapUnlockTitle(int from, int to) {
    return 'Unlock levels $from–$to';
  }

  @override
  String get iapUnlockHeadline => 'Support your child\'s Bible learning';

  @override
  String get iapUnlockBody => 'One payment unlocks every remaining level, forever. Levels 1–5 and Practice mode stay free.';

  @override
  String get iapUnlockBenefitLevels => '95 more levels of Bible character challenges';

  @override
  String get iapUnlockBenefitOneTime => 'One-time payment — no subscription';

  @override
  String get iapUnlockBenefitPractice => 'Practice mode always stays free';

  @override
  String get iapUnlockPriceLoading => 'Checking price…';

  @override
  String iapUnlockBuyAction(String price) {
    return 'Unlock for $price';
  }

  @override
  String get iapUnlockLater => 'Maybe later';

  @override
  String get iapStoreUnavailable => 'The store is unavailable right now.';

  @override
  String get iapAlreadyPurchasedRestoring => 'You\'ve already purchased this! Restoring your access…';

  @override
  String get purchaseSuccessTitle => 'You\'re all set!';

  @override
  String purchaseSuccessBody(int from, int to) {
    return 'Levels $from–$to are unlocked. Happy playing!';
  }

  @override
  String get purchaseSuccessAction => 'Continue playing';

  @override
  String get purchaseFailedTitle => 'Purchase didn\'t go through';

  @override
  String get purchaseFailedBody => 'You have not been charged. You can try again, or contact us and we\'ll help.';

  @override
  String get purchaseCancelledNotice => 'Purchase cancelled. Levels 6–100 are still locked.';

  @override
  String get restorePurchaseTitle => 'Restore purchase';

  @override
  String get restorePurchaseBody => 'If you\'ve already paid, we\'ll restore your access. Make sure you\'re signed in to the store account you paid with.';

  @override
  String get restorePurchaseAction => 'Restore purchase';

  @override
  String get restorePurchaseSuccess => 'Your purchase has been restored.';

  @override
  String get restorePurchaseNothing => 'There\'s no previous purchase to restore on this store account.';

  @override
  String get restorePurchaseError => 'Couldn\'t restore your purchase. Please try again later.';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardWindowAllTime => 'All time';

  @override
  String get leaderboardWindowWeekly => 'This week';

  @override
  String get leaderboardWindowDaily => 'Today';

  @override
  String get leaderboardColumnRank => 'Rank';

  @override
  String get leaderboardColumnPlayer => 'Player';

  @override
  String get leaderboardColumnScore => 'Score';

  @override
  String get leaderboardYourRank => 'Your rank';

  @override
  String leaderboardYourRankValue(int rank, int score) {
    return '#$rank · $score points';
  }

  @override
  String get leaderboardYourRankNone => 'Complete a level to join the board.';

  @override
  String get leaderboardEmpty => 'Be the first! Complete a level to submit your score.';

  @override
  String get leaderboardOffline => 'Leaderboard needs internet. Connect to see rankings.';

  @override
  String get leaderboardError => 'Couldn\'t load leaderboard. Pull down to refresh.';

  @override
  String leaderboardUpdatedAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String get leaderboardUpdatedJustNow => 'Updated just now';

  @override
  String leaderboardLevelLabel(int number) {
    return 'Level $number';
  }

  @override
  String get practiceHubTitle => 'Practice';

  @override
  String get practiceHubSubhead => 'Levels 1–5 offline. No ads, no scores, no internet needed.';

  @override
  String get practiceLevelOfflineOnly => 'Offline practice is available for levels 1–5 only.';

  @override
  String get practiceOfflineBadge => 'Works offline';

  @override
  String practiceQuestionsUpdated(String date) {
    return 'Questions updated $date';
  }

  @override
  String get practiceUpdating => 'Updating practice questions…';

  @override
  String get practiceUpdateFailed => 'Couldn\'t update practice questions. Using saved questions.';

  @override
  String get practiceNoPackOffline => 'Practice questions need a one-time download. Connect to the internet, then open Practice again.';

  @override
  String get practiceNoPackRetry => 'Retry when online';

  @override
  String get practicePackCorrupt => 'Practice questions couldn\'t load. Try reinstalling the app or contact support.';

  @override
  String get practiceLevelNotReady => 'This level has no practice questions yet.';

  @override
  String get practiceResultPassTitle => 'Well done!';

  @override
  String practiceResultPassBody(int count) {
    return 'You answered all $count questions correctly.';
  }

  @override
  String get practiceResultFailTitle => 'Good practice!';

  @override
  String practiceResultFailBody(int correct, int total) {
    return 'You got $correct of $total before the level ended.';
  }

  @override
  String get practiceResultTryMain => 'Play this level for real';

  @override
  String get practiceResultTryAgain => 'Practice again';

  @override
  String get practiceResultBack => 'Back to practice';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileStatLevels => 'Levels completed';

  @override
  String get profileStatHighest => 'Highest level';

  @override
  String get profileStatScore => 'Total score';

  @override
  String get profilePurchaseUnlocked => 'Levels 6–100 unlocked';

  @override
  String get profilePurchaseLocked => 'Levels 6–100 locked';

  @override
  String profileMemberSince(String date) {
    return 'Playing since $date';
  }

  @override
  String get profileAgeGroupKid => 'Kids';

  @override
  String get profileAgeGroupYouth => 'Youth';

  @override
  String get profileAgeGroupAdult => 'Adult';

  @override
  String get profileAgeGroupElder => 'Elder';

  @override
  String profileSignedInWith(String provider) {
    return 'Signed in with $provider';
  }

  @override
  String get profileLinkSettings => 'Settings';

  @override
  String get profileLinkSupport => 'Help & Support';

  @override
  String get profileLinkDelete => 'Delete my account';

  @override
  String get profileRefreshFailed => 'Couldn\'t refresh profile';

  @override
  String get profileUnlockAction => 'Unlock all levels';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionDisplay => 'Display';

  @override
  String get settingsLargeText => 'Large text';

  @override
  String get settingsLargeTextSubtitle => 'Bigger type across the whole app.';

  @override
  String get settingsThemeMode => 'Appearance';

  @override
  String get settingsThemeSystem => 'Match device';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsSectionReminders => 'Reminders';

  @override
  String get settingsPlayReminders => 'Play reminders';

  @override
  String get settingsPlayRemindersSubtitle => 'One gentle nudge if you haven\'t played in a few days.';

  @override
  String get settingsRemindersBlocked => 'Notifications are switched off for Anointed in your device settings.';

  @override
  String get settingsOpenDeviceSettings => 'Open device settings';

  @override
  String get settingsSectionPurchases => 'Purchases';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String settingsAppVersion(String version, String build) {
    return 'Anointed v$version build $build';
  }

  @override
  String get settingsSaveFailed => 'Couldn\'t save that setting. Please try again.';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody => 'You\'ll need to sign in again to see your progress on this device.';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody => 'Deleting your account will permanently remove all your progress, scores, and data. This cannot be undone.';

  @override
  String get deleteAccountChildNote => 'Your child\'s data will be permanently removed from our servers immediately.';

  @override
  String get deleteAccountRemovedHeading => 'What gets deleted';

  @override
  String get deleteAccountRetainedHeading => 'What we keep, with no link to you';

  @override
  String get deleteAccountFirstAction => 'Delete account';

  @override
  String get deleteAccountFinalTitle => 'One last check';

  @override
  String get deleteAccountAcknowledge => 'I understand this is permanent and cannot be undone.';

  @override
  String get deleteAccountConfirmAction => 'Confirm deletion';

  @override
  String get deleteAccountDoneTitle => 'Your account has been deleted.';

  @override
  String get deleteAccountDoneBody => 'Thanks for playing Anointed. We\'re returning you to the start.';

  @override
  String get deleteAccountFailed => 'Couldn\'t delete your account right now. Please try again or contact support.';

  @override
  String deleteAccountStatLevels(int count) {
    return '$count levels completed will be removed';
  }

  @override
  String get deleteAccountPurchaseNote => 'Your purchase cannot be transferred to a new account. Store refunds are handled by Apple or Google.';

  @override
  String get supportTitle => 'Help & Support';

  @override
  String get supportFaqHeading => 'Frequently asked questions';

  @override
  String get supportFaqEmpty => 'No FAQ available right now.';

  @override
  String get supportContactHeading => 'Contact us';

  @override
  String get supportCategoryLabel => 'What\'s this about?';

  @override
  String get supportCategoryGeneral => 'General question';

  @override
  String get supportCategoryAccount => 'Account and sign-in';

  @override
  String get supportCategoryPurchase => 'Purchases';

  @override
  String get supportCategoryGameplay => 'Playing the game';

  @override
  String get supportCategoryPrivacy => 'Privacy';

  @override
  String get supportMessageLabel => 'Your message';

  @override
  String get supportMessageRequired => 'Please write a little more so we can help.';

  @override
  String get supportReplyToLabel => 'Email for our reply (optional)';

  @override
  String get supportSendAction => 'Send message';

  @override
  String get supportSendSuccess => 'Thanks — we\'ve got your message and will reply by email.';

  @override
  String supportSendFailed(String email) {
    return 'Couldn\'t send your message. Try again or email $email directly.';
  }

  @override
  String supportEmailDirect(String email) {
    return 'Email us at $email';
  }

  @override
  String get supportEmailUsAction => 'Email us instead';

  @override
  String get supportContactSubhead => 'Describe what happened and include any details that will help us (your sign-in method, level number, or purchase receipt). We reply by email, usually within one business day.';

  @override
  String get supportSignInRequired => 'You need to be signed in to read the FAQ or send a message from the app. You can still email us directly.';

  @override
  String supportEmailCopyHint(String email) {
    return 'No email app found. Write to us at $email.';
  }

  @override
  String get supportVersionNote => 'Include your app version when you contact us — it\'s shown below.';

  @override
  String get notificationChannelName => 'Play reminders';

  @override
  String get notificationChannelDescription => 'Gentle reminders to come back and play.';

  @override
  String get notification3dTitle => 'Anointed';

  @override
  String notification3dBody(int level) {
    return 'Level $level is waiting! Come back to Anointed.';
  }

  @override
  String get notification7dTitle => 'Anointed';

  @override
  String get notification7dBody => 'We miss you! Pick up your Bible character quiz.';

  @override
  String get devSignInTitle => 'Developer sign-in';

  @override
  String get devSignInBody => 'Google and Apple sign-in are not configured in this build. Continue with a development account instead.';

  @override
  String get devSignInAction => 'Continue as developer account';

  @override
  String get devSignInBadge => 'Development build';

  @override
  String get playModeChooserHeading => 'Choose your journey';

  @override
  String get playModeMainJourneyTitle => 'Main Journey';

  @override
  String get playModeMainJourneySubtitle => '100 levels · leaderboard · ranked play';

  @override
  String get playModeKidsZoneTitle => 'Kids Zone';

  @override
  String get playModeKidsZoneSubtitle => 'Adventure games · stories · stars';

  @override
  String get kidsZoneHubTitle => 'Kids Zone';

  @override
  String get kidsZoneHubSubhead => 'Pick an adventure — animated stories, games, and stars!';

  @override
  String get kidsZoneBackToMain => 'Back to Main Journey';

  @override
  String kidsZoneAdventureStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get kidsZoneStopComplete => 'Done!';

  @override
  String get kidsZoneStopLocked => 'Finish the stop before this one first';

  @override
  String get kidsZoneStopPlay => 'Start adventure';

  @override
  String get kidsZoneStopReplay => 'Play again';

  @override
  String get kidsZonePackNotReady => 'Adventure questions aren\'t ready yet. Connect to the internet or try again.';

  @override
  String get kidsZoneWrongFriendly => 'Good try! Tap another answer.';

  @override
  String get kidsZoneCompleteTitle => 'Adventure complete!';

  @override
  String kidsZoneCompleteStars(int stars) {
    return 'You earned $stars stars!';
  }

  @override
  String get kidsZoneCompleteNext => 'Next stop';

  @override
  String get kidsZoneCompleteExplore => 'Explore more adventures';

  @override
  String get kidsZoneGameplayHint => 'Take your time — wrong answers let you try again!';

  @override
  String get kidsZoneGameStory => 'Story adventure';

  @override
  String get kidsZoneGameListen => 'Listen & learn';

  @override
  String get kidsZoneGameIntro => 'Introduction';

  @override
  String get kidsZoneGameConnect => 'Connect creations';

  @override
  String get kidsZoneGameJumble => 'Jumbled challenge';

  @override
  String get kidsZoneGameMatch => 'Match game';

  @override
  String get kidsZoneGameTrail => 'Story trail';

  @override
  String get kidsZoneGameExplorer => 'Explorer hunt';

  @override
  String get kidsZoneGameArchery => 'Archery quest';

  @override
  String get kidsZoneGameArkBuilder => 'Ark builder';

  @override
  String get kidsZoneGameAnimalMatch => 'Two by two';

  @override
  String get kidsZoneGameAnimalCare => 'Animal care';

  @override
  String get kidsZoneGameFinish => 'Finish adventure';

  @override
  String get kidsZoneGameMissing => 'This adventure game isn\'t ready yet.';

  @override
  String kidsZoneGameMatchProgress(int found, int total) {
    return 'Pairs found: $found of $total';
  }

  @override
  String get kidsZoneGameTrailHint => 'Drag the stones to put the story in order.';

  @override
  String get kidsZoneGameTrailWrong => 'Not quite — try a different order!';

  @override
  String get kidsZoneGameTrailCheck => 'Check my trail';

  @override
  String get kidsZoneGameShuffle => 'Shuffle stones';

  @override
  String kidsZoneGameExplorerProgress(int found, int total) {
    return 'Found $found of $total';
  }

  @override
  String get kidsZoneListenIntro => 'Listen carefully to the whole story. Questions come after!';

  @override
  String kidsZoneListenPart(int current, int total) {
    return 'Part $current of $total';
  }

  @override
  String get kidsZoneListenPlay => 'Listen again';

  @override
  String get kidsZoneListenPlaying => 'Listening…';

  @override
  String get kidsZoneListenNext => 'Next part';

  @override
  String get kidsZoneListenReady => 'I\'m ready for questions';

  @override
  String get kidsZoneQuestionIntro => 'Great listening! Now show what you heard.';

  @override
  String get kidsZoneListenWrong => 'Think about the story — try another answer!';

  @override
  String get kidsZoneIntroSceneHint => 'Listen to the Creation story. Watch the world come alive!';

  @override
  String get kidsZoneIntroBeginLevel1 => 'Start Level 1';

  @override
  String get kidsZoneLevel1Intro => 'Listen to each question, then choose your answer.';

  @override
  String get kidsZoneListenNowListen => 'Listen to the question…';

  @override
  String get kidsZoneListenChooseAnswer => 'Now choose your answer';

  @override
  String get kidsZoneConnectHint => 'Tap a day, then tap what God made that day. Careful — some things were not made in creation week!';

  @override
  String get kidsZoneConnectDistractor => 'Some of those were not part of creation week. Look again!';

  @override
  String get kidsZoneConnectWrong => 'Some connections aren\'t right — try again!';

  @override
  String get kidsZoneConnectCheck => 'Check my connections';

  @override
  String get kidsZoneConnectReset => 'Clear all lines';

  @override
  String kidsZoneJumbleProgress(int current, int total) {
    return 'Sentence $current of $total';
  }

  @override
  String get kidsZoneJumbleTapWords => 'Tap the words in order to build the sentence';

  @override
  String kidsZoneJumbleHint(String word) {
    return 'Try this word next: $word';
  }

  @override
  String get kidsZoneJumbleCheck => 'Check sentence';

  @override
  String get kidsZoneJumbleReset => 'Start this sentence over';

  @override
  String get kidsZoneJumbleComplete => 'You unscrambled Creation! Rainbow celebration!';

  @override
  String get kidsZoneSiddimIntroHint => 'Hear how Abram bravely rescued Lot in the Valley of Siddim.';

  @override
  String get kidsZoneSiddimBeginLevel1 => 'Start the archery quest';

  @override
  String get kidsZoneSiddimAimHint => 'Drag to aim · let go to shoot · keep soldiers out of the camp';

  @override
  String kidsZoneSiddimRoundLabel(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String kidsZoneSiddimCourageLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courage hearts left',
      one: '1 courage heart left',
    );
    return '$_temp0';
  }

  @override
  String get kidsZoneSiddimRoundCleared => 'Round cleared!';

  @override
  String kidsZoneSiddimRoundStats(int score, int accuracy) {
    return '$score points · $accuracy% accuracy';
  }

  @override
  String get kidsZoneSiddimVictoryTitle => 'Abram wins the day!';

  @override
  String get kidsZoneSiddimVictoryBody => 'King Chedorlaomer turns back and Lot comes home safe.';

  @override
  String get kidsZoneSiddimBreached => 'The soldiers reached the camp';

  @override
  String get kidsZoneSiddimBreachedBody => 'Abram never gave up — and neither should you. Try this round again!';

  @override
  String get kidsZoneSiddimTryRoundAgain => 'Try this round again';

  @override
  String get kidsZoneSiddimNearMiss => 'Almost!';

  @override
  String get kidsZoneSiddimAimHintAccessible => 'Choose a lane to shoot along';

  @override
  String get kidsZoneSiddimStatTurnedBack => 'Soldiers turned back';

  @override
  String get kidsZoneSiddimStatArrows => 'Arrows on target';

  @override
  String get kidsZoneSiddimStatHearts => 'Hearts left';

  @override
  String get kidsZoneSiddimStatPoints => 'Points';

  @override
  String get kidsZoneSiddimGoalNoBreach => 'Let nobody reach the camp';

  @override
  String kidsZoneSiddimGoalAccuracy(int percent) {
    return 'Hit with $percent% of your arrows';
  }

  @override
  String get kidsZoneSiddimLaneFarLeft => 'far left';

  @override
  String get kidsZoneSiddimLaneLeft => 'left';

  @override
  String get kidsZoneSiddimLaneAhead => 'straight ahead';

  @override
  String get kidsZoneSiddimLaneRight => 'right';

  @override
  String get kidsZoneSiddimLaneFarRight => 'far right';

  @override
  String kidsZoneSiddimFireLane(String lane) {
    return 'Shoot $lane';
  }

  @override
  String get kidsZoneSiddimThreatNone => 'The valley is clear';

  @override
  String kidsZoneSiddimThreatAt(String lane) {
    return 'Nearest soldier: $lane';
  }

  @override
  String get kidsZoneArkIntroHint => 'Hear how Noah trusted God, built the ark, and kept every animal safe.';

  @override
  String get kidsZoneArkBeginLevel1 => 'Start building the ark';

  @override
  String kidsZoneArkStageLabel(int stage, int total) {
    return 'Stage $stage of $total';
  }

  @override
  String kidsZoneArkPiecePlaced(String piece) {
    return '$piece fitted';
  }

  @override
  String get kidsZoneArkTrayEmpty => 'Every piece is in place!';

  @override
  String get kidsZoneArkStageDone => 'Stage complete!';

  @override
  String get kidsZoneArkStageNext => 'Noah kept working day after day. Let\'s keep going!';

  @override
  String get kidsZoneArkKeepBuilding => 'Keep building';

  @override
  String get kidsZoneArkBuiltTitle => 'The ark is finished!';

  @override
  String get kidsZoneArkBuiltBody => 'Noah obeyed God and finished every plank. Well done!';

  @override
  String get kidsZoneArkMatchHint => 'Flip two cards to find each animal and its mate. You have 5 hearts!';

  @override
  String kidsZoneArkPairsFound(int found, int total) {
    return 'Pairs: $found of $total';
  }

  @override
  String kidsZoneArkLivesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hearts left',
      one: '1 heart left',
    );
    return '$_temp0';
  }

  @override
  String kidsZoneArkPairFound(String animal) {
    return '$animal pair found';
  }

  @override
  String get kidsZoneArkMatchWonTitle => 'Every animal is aboard!';

  @override
  String get kidsZoneArkMatchWonBody => 'Two by two, just as God told Noah.';

  @override
  String get kidsZoneArkMatchLostTitle => 'Out of hearts';

  @override
  String get kidsZoneArkMatchLostBody => 'Noah never gave up. Shall we try once more?';

  @override
  String get kidsZoneArkTryAgain => 'Try again';

  @override
  String get kidsZoneArkPracticeMode => 'Practice mode: unlimited hearts';

  @override
  String get kidsZoneArkHeartsUnlimited => 'Unlimited hearts';

  @override
  String get kidsZoneArkMercyReveal => 'Here they are! Remember where they go.';

  @override
  String get kidsZoneArkPracticeStar => 'Practice run — play with hearts to earn more stars.';

  @override
  String kidsZoneArkRoundLabel(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String kidsZoneArkTasks(int done, int total) {
    return 'Cared for $done of $total';
  }

  @override
  String kidsZoneArkHappiness(int percent) {
    return 'Animals are $percent% happy';
  }

  @override
  String get kidsZoneArkToolFood => 'Feed';

  @override
  String get kidsZoneArkToolWater => 'Water';

  @override
  String get kidsZoneArkToolClean => 'Clean';

  @override
  String get kidsZoneArkToolComfort => 'Comfort';

  @override
  String get kidsZoneArkPickToolFirst => 'Pick a tool first, then tap the animal.';

  @override
  String kidsZoneArkCared(String animal) {
    return '$animal is happy';
  }

  @override
  String get kidsZoneArkRoundDone => 'Round complete!';

  @override
  String get kidsZoneArkNextRound => 'Next round';

  @override
  String get kidsZoneArkCareDoneTitle => 'A safe voyage!';

  @override
  String get kidsZoneArkCareDoneBody => 'You cared for every animal until the waters went down.';

  @override
  String get kidsZoneArkTutorialTitle => 'How to help the animals';

  @override
  String get kidsZoneArkTutorialBody => 'An animal shows a picture of what it needs. Pick the matching tool, then tap that animal.';

  @override
  String get kidsZoneArkTutorialStart => 'I\'m ready!';

  @override
  String get kidsZoneArkTutorialHelp => 'How to play';

  @override
  String get kidsZoneGameRiverRescue => 'River rescue';

  @override
  String get kidsZoneMosesIntroHint => 'Listen to the story of baby Moses on the river.';

  @override
  String get kidsZoneMosesBeginLevel1 => 'Begin Level 1';

  @override
  String get kidsZoneGamePlagueSort => 'Plagues of Egypt';

  @override
  String get kidsZoneGameSeaCrossing => 'Crossing the sea';

  @override
  String kidsZoneSeaPhaseLabel(int phase, int total) {
    return 'Part $phase of $total';
  }

  @override
  String kidsZoneSeaBeatsSemantics(int hits, int total) {
    return '$hits of $total beats kept';
  }

  @override
  String kidsZonePlagueRoundLabel(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String kidsZonePlagueStep(int step) {
    return '$step';
  }

  @override
  String get kidsZonePlagueResolveLabel => 'Pharaoh\'s heart';

  @override
  String get kidsZonePlagueResolveBroken => 'Pharaoh lets them go!';

  @override
  String kidsZonePlagueResolveSemantics(int cracks, int total) {
    return 'Pharaoh\'s heart: $cracks of $total cracks';
  }

  @override
  String kidsZonePlagueCardSemantics(String name) {
    return '$name. Drag onto the right step.';
  }

  @override
  String kidsZonePlagueHearSemantics(String name) {
    return 'Hear about $name';
  }

  @override
  String kidsZonePlaguePlaced(String name) {
    return '$name is in the right place';
  }

  @override
  String get kidsZonePlaguePreviewToggle => 'Watch it once first';

  @override
  String get kidsZonePlagueStart => 'Begin';

  @override
  String get kidsZonePlagueRoundDone => 'Pharaoh\'s heart cracks!';

  @override
  String kidsZonePlagueRoundDoneBody(int round, int total) {
    return 'Round $round of $total is done. Egypt has not seen the last of this.';
  }

  @override
  String get kidsZonePlagueNextRound => 'Keep going';

  @override
  String get kidsZonePlagueDoneTitle => 'Let my people go';

  @override
  String get kidsZonePlagueDoneBody => 'The crown has fallen. Pharaoh finally lets God\'s people leave Egypt.';

  @override
  String get kidsZonePlagueCollectStars => 'Collect my stars';

  @override
  String get kidsZonePlagueSayBlood => 'I stretched out my staff, and the Nile turned to blood.';

  @override
  String get kidsZonePlagueSayFrogs => 'Then frogs came up out of the river, into every house in Egypt.';

  @override
  String get kidsZonePlagueSayGnats => 'The dust of the ground became gnats, all over the land.';

  @override
  String get kidsZonePlagueSayFlies => 'Great swarms of flies filled Pharaoh\'s palace.';

  @override
  String get kidsZonePlagueSayLivestock => 'The animals in the fields grew sick, but not one of ours.';

  @override
  String get kidsZonePlagueSayBoils => 'Sores broke out on the people of Egypt, and Pharaoh still said no.';

  @override
  String get kidsZonePlagueSayHail => 'Hail and fire fell together out of the sky.';

  @override
  String get kidsZonePlagueSayLocusts => 'Locusts came in a cloud and ate every green thing left.';

  @override
  String get kidsZonePlagueSayDarkness => 'Darkness covered Egypt for three days, so thick you could feel it.';

  @override
  String get kidsZonePlagueSayFirstborn => 'After the last night, Pharaoh\'s crown fell, and he let my people go.';

  @override
  String kidsZoneRiverStageLabel(int stage, int total) {
    return 'Stage $stage of $total';
  }

  @override
  String kidsZoneRiverDistance(int metres) {
    return '$metres metres travelled';
  }

  @override
  String get kidsZoneRiverExit => 'Leave River Rescue';

  @override
  String kidsZoneRiverBumpToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A splash! $count hearts left — try again!',
      one: 'A splash! One heart left — you can do it!',
      zero: 'A splash! No hearts left, but keep floating!',
    );
    return '$_temp0';
  }

  @override
  String get kidsZoneRiverFreshChanceToast => 'Fresh hearts — a new chance for this stretch!';

  @override
  String kidsZoneRiverHeartsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hearts left',
      one: '1 heart left',
    );
    return '$_temp0';
  }

  @override
  String kidsZoneRiverLotusCount(int collected, int total) {
    return '$collected of $total lotus flowers';
  }

  @override
  String get kidsZoneRiverLaneLeft => 'Left';

  @override
  String get kidsZoneRiverLaneCenter => 'Middle';

  @override
  String get kidsZoneRiverLaneRight => 'Right';

  @override
  String get kidsZoneRiverHop => 'Hop';

  @override
  String get kidsZoneRiverDuck => 'Duck';

  @override
  String get kidsZoneRiverBoost => 'Paddle';

  @override
  String get kidsZoneRiverShielded => 'An angel is watching over you';

  @override
  String get kidsZoneRiverBoosting => 'Paddling fast!';

  @override
  String get kidsZoneRiverBlessingTaken => 'An angel blessing! You are safe for a moment.';

  @override
  String get kidsZoneRiverStageDone => 'You made it!';

  @override
  String kidsZoneRiverStageDoneBody(int stage, int total) {
    return 'Stage $stage of $total is behind you. The river runs faster ahead.';
  }

  @override
  String get kidsZoneRiverNextStage => 'Keep floating';

  @override
  String get kidsZoneRiverDoneTitle => 'Safe in the princess\'s arms';

  @override
  String get kidsZoneRiverDoneBody => 'Baby Moses floated all the way down the Nile, and the princess lifted him out of the water.';

  @override
  String get kidsZoneRiverCollectStars => 'Collect my stars';

  @override
  String get kidsZoneAdventureCreationGardenTitle => 'Creation Garden';

  @override
  String get kidsZoneAdventureCreationGardenSubtitle => 'Genesis — listen, learn, and play';

  @override
  String get kidsZoneAdventureBattleOfSiddimTitle => 'Battle of Siddim';

  @override
  String get kidsZoneAdventureBattleOfSiddimSubtitle => 'Genesis 14 — Abraham\'s archery quest';

  @override
  String get kidsZoneAdventureNoahsArkTitle => 'Noah\'s Ark';

  @override
  String get kidsZoneAdventureNoahsArkSubtitle => 'Genesis 6-9 — a faithful journey';

  @override
  String get kidsZoneAdventureMosesNileTitle => 'Baby Moses';

  @override
  String get kidsZoneAdventureMosesNileSubtitle => 'Exodus 1-2 - down the river to the princess';

  @override
  String get kidsZoneAdventureHeroesPathTitle => 'Heroes Path';

  @override
  String get kidsZoneAdventureHeroesPathSubtitle => 'Coming soon — more Bible adventures';

  @override
  String get kidsZoneAdventureWiseKingsTitle => 'Wise Kings';

  @override
  String get kidsZoneAdventureWiseKingsSubtitle => 'Coming soon';

  @override
  String get kidsZoneStopCreationIntroTitle => 'Introduction';

  @override
  String get kidsZoneStopCreationIntroTeaser => 'Animated story — day by day';

  @override
  String get kidsZoneStopGarden1Title => 'Level 1 — God\'s Questions';

  @override
  String get kidsZoneStopGarden1Teaser => 'Listen & answer about Creation';

  @override
  String get kidsZoneStopGarden2Title => 'Level 2 — Connect Creations';

  @override
  String get kidsZoneStopGarden2Teaser => 'Match days to what God made';

  @override
  String get kidsZoneStopGarden3Title => 'Level 3 — Jumbled Challenge';

  @override
  String get kidsZoneStopGarden3Teaser => 'Unscramble creation sentences';

  @override
  String get kidsZoneStopSiddimIntroTitle => 'Introduction';

  @override
  String get kidsZoneStopSiddimIntroTeaser => 'The valley, the four kings, and Lot';

  @override
  String get kidsZoneStopSiddim1Title => 'Level 1 — Defend the Valley';

  @override
  String get kidsZoneStopSiddim1Teaser => 'Rounds 1-2 — learn to aim and shoot';

  @override
  String get kidsZoneStopSiddim2Title => 'Level 2 — The Night Rescue';

  @override
  String get kidsZoneStopSiddim2Teaser => 'Rounds 3-5 — faster, trickier soldiers';

  @override
  String get kidsZoneStopSiddim3Title => 'Level 3 — King\'s Round';

  @override
  String get kidsZoneStopSiddim3Teaser => 'Round 6 — King Chedorlaomer himself';

  @override
  String get kidsZoneStopArkIntroTitle => 'Introduction';

  @override
  String get kidsZoneStopArkIntroTeaser => 'Noah, the ark, and God\'s promise';

  @override
  String get kidsZoneStopArk1Title => 'Level 1 — Ark Builder';

  @override
  String get kidsZoneStopArk1Teaser => 'Drag the timber into place';

  @override
  String get kidsZoneStopArk2Title => 'Level 2 — Two by Two';

  @override
  String get kidsZoneStopArk2Teaser => 'Memory match — find each animal\'s mate';

  @override
  String get kidsZoneStopArk3Title => 'Level 3 — Animal Care';

  @override
  String get kidsZoneStopArk3Teaser => 'Feed, clean and comfort the animals';

  @override
  String get kidsZoneStopMosesIntroTitle => 'Introduction';

  @override
  String get kidsZoneStopMosesIntroTeaser => 'Pharaoh, a basket of reeds, and a princess';

  @override
  String get kidsZoneStopMoses1Title => 'Level 1 - River Rescue';

  @override
  String get kidsZoneStopMoses1Teaser => 'Steer the basket past reeds, logs and sleepy crocodiles';

  @override
  String get kidsZoneStopMoses2Title => 'Level 2 - Plagues of Egypt';

  @override
  String get kidsZoneStopMoses2Teaser => 'Put the ten plagues in order and watch Egypt answer';

  @override
  String get kidsZoneStopMoses3Title => 'Level 3 - Crossing the Sea';

  @override
  String get kidsZoneStopMoses3Teaser => 'Part the water, walk across, and send the chariots home';

  @override
  String get kidsZoneStopHeroes2Title => 'Young David';

  @override
  String get kidsZoneStopHeroes2Teaser => 'Explore the pasture';

  @override
  String get kidsZoneStopKings1Title => 'Solomon\'s Gift';

  @override
  String get kidsZoneStopKings1Teaser => 'Story adventure';
}
