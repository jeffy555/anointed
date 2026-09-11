import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Anointed'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Discover the people of the Bible'**
  String get appTagline;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionBackToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to map'**
  String get actionBackToMap;

  /// No description provided for @actionContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get actionContactSupport;

  /// No description provided for @actionUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get actionUpdateNow;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get errorGenericBody;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and try again.'**
  String get errorOfflineBody;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errorSessionExpired;

  /// No description provided for @errorLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {url} on this device.'**
  String errorLinkFailed(String url);

  /// No description provided for @offlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineBadge;

  /// No description provided for @splashCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Getting things ready…'**
  String get splashCheckingUpdates;

  /// No description provided for @splashConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect to check for updates.'**
  String get splashConnectionError;

  /// No description provided for @forceUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get forceUpgradeTitle;

  /// No description provided for @forceUpgradeBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of Anointed is available. Please update to continue playing.'**
  String get forceUpgradeBody;

  /// No description provided for @forceUpgradeReleaseNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get forceUpgradeReleaseNotesLabel;

  /// No description provided for @forceUpgradeStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store. Please update Anointed from your app store.'**
  String get forceUpgradeStoreUnavailable;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Learn the people of the Bible'**
  String get welcomeHeadline;

  /// No description provided for @welcomeSubhead.
  ///
  /// In en, this message translates to:
  /// **'100 levels of Bible character challenges.'**
  String get welcomeSubhead;

  /// No description provided for @welcomeContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get welcomeContinueWithGoogle;

  /// No description provided for @welcomeContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get welcomeContinueWithApple;

  /// No description provided for @welcomeContinueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone number'**
  String get welcomeContinueWithPhone;

  /// No description provided for @welcomeSaveProgressNote.
  ///
  /// In en, this message translates to:
  /// **'Save your progress on any device'**
  String get welcomeSaveProgressNote;

  /// No description provided for @welcomeOrDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get welcomeOrDivider;

  /// No description provided for @welcomeAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get welcomeAlreadyHaveAccount;

  /// No description provided for @welcomeSignInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get welcomeSignInLink;

  /// No description provided for @welcomeOauthFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with {provider}. Try again or use phone number.'**
  String welcomeOauthFailed(String provider);

  /// No description provided for @providerGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get providerGoogle;

  /// No description provided for @providerApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get providerApple;

  /// No description provided for @providerPhone.
  ///
  /// In en, this message translates to:
  /// **'phone number'**
  String get providerPhone;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubhead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pick up where you left off.'**
  String get signInSubhead;

  /// No description provided for @signInWithPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number'**
  String get signInWithPhoneTitle;

  /// No description provided for @signInAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an account with that mobile number and name. Double-check both fields match what you used at sign-up.'**
  String get signInAccountNotFound;

  /// No description provided for @signInCreateAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get signInCreateAccountLink;

  /// No description provided for @signInNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Contact support for account recovery'**
  String get signInNeedHelp;

  /// No description provided for @signInPhoneRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the same mobile number and display name you used when you created your account. Spelling must match exactly.'**
  String get signInPhoneRecoveryHint;

  /// No description provided for @signInRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting your progress back'**
  String get signInRecoveryTitle;

  /// No description provided for @signInRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'If you originally signed up with Google or Apple, use that button above — your progress is tied to that account.\n\nFor phone accounts, both the number and name must match exactly. On a new device, enter the same details you used before.\n\nStill stuck? Contact support with your mobile number and the name on the account.'**
  String get signInRecoveryBody;

  /// No description provided for @signInRecoveryPrevent.
  ///
  /// In en, this message translates to:
  /// **'Tip: write down the name you chose at sign-up. Phone accounts do not use SMS codes — your number plus that exact name is how we find you.'**
  String get signInRecoveryPrevent;

  /// No description provided for @phoneSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get phoneSignUpTitle;

  /// No description provided for @phoneSignUpSubhead.
  ///
  /// In en, this message translates to:
  /// **'No verification code needed.'**
  String get phoneSignUpSubhead;

  /// No description provided for @fieldMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get fieldMobileLabel;

  /// No description provided for @fieldMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Numbers only'**
  String get fieldMobileHint;

  /// No description provided for @fieldNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fieldNameLabel;

  /// No description provided for @fieldAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get fieldAgeLabel;

  /// No description provided for @fieldMobileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number.'**
  String get fieldMobileInvalid;

  /// No description provided for @fieldNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get fieldNameRequired;

  /// No description provided for @fieldAgeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age between 4 and 120.'**
  String get fieldAgeInvalid;

  /// No description provided for @phoneSignUpAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with that number and name. Try signing in instead.'**
  String get phoneSignUpAccountExists;

  /// No description provided for @phoneSignUpCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get phoneSignUpCreateAction;

  /// No description provided for @profileCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get profileCompletionTitle;

  /// No description provided for @profileCompletionSubhead.
  ///
  /// In en, this message translates to:
  /// **'We ask for age so we can keep younger players safe.'**
  String get profileCompletionSubhead;

  /// No description provided for @parentGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask a parent or guardian to continue'**
  String get parentGateTitle;

  /// No description provided for @parentGateBody.
  ///
  /// In en, this message translates to:
  /// **'Because this player is under 13, a parent or guardian needs to give permission before the account can be used. A grown-up should take over from here.'**
  String get parentGateBody;

  /// No description provided for @parentGateNoSkipNote.
  ///
  /// In en, this message translates to:
  /// **'This step can\'t be skipped.'**
  String get parentGateNoSkipNote;

  /// No description provided for @parentGatePathATitle.
  ///
  /// In en, this message translates to:
  /// **'Parent signs in (recommended)'**
  String get parentGatePathATitle;

  /// No description provided for @parentGatePathABody.
  ///
  /// In en, this message translates to:
  /// **'A parent signs in with their own Google or Apple account and gives permission.'**
  String get parentGatePathABody;

  /// No description provided for @parentGatePathBTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent email confirmation'**
  String get parentGatePathBTitle;

  /// No description provided for @parentGatePathBBody.
  ///
  /// In en, this message translates to:
  /// **'We email a parent a secure link they open on their own device.'**
  String get parentGatePathBBody;

  /// No description provided for @parentGateStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'The previous permission link expired. Please start again.'**
  String get parentGateStatusExpired;

  /// No description provided for @parentGateStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian declined permission for this account.'**
  String get parentGateStatusDenied;

  /// No description provided for @parentOauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent, please sign in'**
  String get parentOauthTitle;

  /// No description provided for @parentOauthBody.
  ///
  /// In en, this message translates to:
  /// **'Use your own Google or Apple account — not your child\'s. You\'ll be asked to choose an account.'**
  String get parentOauthBody;

  /// No description provided for @parentOauthWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue as parent with Google'**
  String get parentOauthWithGoogle;

  /// No description provided for @parentOauthWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue as parent with Apple'**
  String get parentOauthWithApple;

  /// No description provided for @parentOauthSameAccountError.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with a parent or guardian\'s own account, not the child\'s.'**
  String get parentOauthSameAccountError;

  /// No description provided for @attestationTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent permission'**
  String get attestationTitle;

  /// No description provided for @attestationGuardianNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian full name'**
  String get attestationGuardianNameLabel;

  /// No description provided for @attestationGuardianNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the parent or guardian\'s full name.'**
  String get attestationGuardianNameRequired;

  /// No description provided for @attestationRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship to the child'**
  String get attestationRelationshipLabel;

  /// No description provided for @relationshipParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get relationshipParent;

  /// No description provided for @relationshipGuardian.
  ///
  /// In en, this message translates to:
  /// **'Legal guardian'**
  String get relationshipGuardian;

  /// No description provided for @relationshipOther.
  ///
  /// In en, this message translates to:
  /// **'Other legal guardian'**
  String get relationshipOther;

  /// No description provided for @attestationIsGuardianCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I am the parent or legal guardian of this child.'**
  String get attestationIsGuardianCheckbox;

  /// No description provided for @attestationConsentCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I consent to the collection and use of my child\'s information as described in the Privacy Policy.'**
  String get attestationConsentCheckbox;

  /// No description provided for @attestationPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Read the Privacy Policy'**
  String get attestationPrivacyLink;

  /// No description provided for @attestationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Both permission checkboxes must be ticked to continue.'**
  String get attestationIncomplete;

  /// No description provided for @childProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your child\'s profile'**
  String get childProfileTitle;

  /// No description provided for @childProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Child\'s display name'**
  String get childProfileNameLabel;

  /// No description provided for @childProfileMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Child\'s mobile number (optional)'**
  String get childProfileMobileLabel;

  /// No description provided for @childProfileAgeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Age: {age}'**
  String childProfileAgeReadOnly(int age);

  /// No description provided for @childProfileSubmit.
  ///
  /// In en, this message translates to:
  /// **'Give permission and continue'**
  String get childProfileSubmit;

  /// No description provided for @parentEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent\'s email address'**
  String get parentEmailTitle;

  /// No description provided for @parentEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Enter a parent or guardian\'s email address — not the child\'s. We\'ll send a secure link that expires in 72 hours.'**
  String get parentEmailBody;

  /// No description provided for @parentEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent\'s email address'**
  String get parentEmailLabel;

  /// No description provided for @parentEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get parentEmailInvalid;

  /// No description provided for @parentEmailSend.
  ///
  /// In en, this message translates to:
  /// **'Send permission email'**
  String get parentEmailSend;

  /// No description provided for @awaitingEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a parent'**
  String get awaitingEmailTitle;

  /// No description provided for @awaitingEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. A parent must tap the link to continue.'**
  String awaitingEmailBody(String email);

  /// No description provided for @awaitingEmailChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for permission…'**
  String get awaitingEmailChecking;

  /// No description provided for @awaitingEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get awaitingEmailResend;

  /// No description provided for @awaitingEmailResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend available in {seconds}s'**
  String awaitingEmailResendIn(int seconds);

  /// No description provided for @awaitingEmailResendSent.
  ///
  /// In en, this message translates to:
  /// **'Permission email sent again.'**
  String get awaitingEmailResendSent;

  /// No description provided for @awaitingEmailSwitchToOauth.
  ///
  /// In en, this message translates to:
  /// **'Use Google or Apple instead'**
  String get awaitingEmailSwitchToOauth;

  /// No description provided for @awaitingEmailExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'This link expires {date}.'**
  String awaitingEmailExpiresAt(String date);

  /// No description provided for @awaitingEmailResendLimit.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent the maximum number of permission emails for today.'**
  String get awaitingEmailResendLimit;

  /// No description provided for @childNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get childNoticeTitle;

  /// No description provided for @childNoticeIntro.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what Anointed keeps, in plain language.'**
  String get childNoticeIntro;

  /// No description provided for @childNoticeItemName.
  ///
  /// In en, this message translates to:
  /// **'A display name, so we can greet the player and show them on the leaderboard as a first name and last initial.'**
  String get childNoticeItemName;

  /// No description provided for @childNoticeItemAge.
  ///
  /// In en, this message translates to:
  /// **'Age, so we know which rules to follow for younger players.'**
  String get childNoticeItemAge;

  /// No description provided for @childNoticeItemProgress.
  ///
  /// In en, this message translates to:
  /// **'Levels completed and scores, so progress is saved.'**
  String get childNoticeItemProgress;

  /// No description provided for @childNoticeItemNoAds.
  ///
  /// In en, this message translates to:
  /// **'Players under 13 never see ads.'**
  String get childNoticeItemNoAds;

  /// No description provided for @childNoticeItemDelete.
  ///
  /// In en, this message translates to:
  /// **'A parent can delete everything at any time from the Profile screen.'**
  String get childNoticeItemDelete;

  /// No description provided for @childNoticeAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get childNoticeAcknowledge;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and Terms'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Continue to accept the Privacy Policy and Terms of Service.'**
  String get privacyBody;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLink;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsLink;

  /// No description provided for @privacyLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that page right now.'**
  String get privacyLinkUnavailable;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// No description provided for @navPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get navPractice;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @levelMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Level map'**
  String get levelMapTitle;

  /// No description provided for @levelMapProgress.
  ///
  /// In en, this message translates to:
  /// **'Level {current} of {total}'**
  String levelMapProgress(int current, int total);

  /// No description provided for @levelMapSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Your progress couldn\'t sync. Playing with last saved data.'**
  String get levelMapSyncFailed;

  /// No description provided for @levelNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String levelNodeLabel(int number);

  /// No description provided for @levelNodeStateLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get levelNodeStateLocked;

  /// No description provided for @levelNodeStateUnlocked.
  ///
  /// In en, this message translates to:
  /// **'unlocked'**
  String get levelNodeStateUnlocked;

  /// No description provided for @levelNodeStateCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get levelNodeStateCompleted;

  /// No description provided for @levelNodeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Level {number} — {state}'**
  String levelNodeSemantics(int number, String state);

  /// No description provided for @levelMapUnlockBanner.
  ///
  /// In en, this message translates to:
  /// **'Unlock levels {from}–{to}'**
  String levelMapUnlockBanner(int from, int to);

  /// No description provided for @levelMapConsentPending.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian needs to finish giving permission before you can play.'**
  String get levelMapConsentPending;

  /// No description provided for @levelMapConsentPendingAction.
  ///
  /// In en, this message translates to:
  /// **'Finish parent permission'**
  String get levelMapConsentPendingAction;

  /// No description provided for @levelDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String levelDetailTitle(int number);

  /// No description provided for @levelDetailDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get levelDetailDifficulty;

  /// No description provided for @levelDetailTimer.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s per question'**
  String levelDetailTimer(int seconds);

  /// No description provided for @levelDetailQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String levelDetailQuestions(int count);

  /// No description provided for @levelDetailQuestionMix.
  ///
  /// In en, this message translates to:
  /// **'Question types'**
  String get levelDetailQuestionMix;

  /// No description provided for @levelDetailBestScore.
  ///
  /// In en, this message translates to:
  /// **'Best score: {score}'**
  String levelDetailBestScore(int score);

  /// No description provided for @levelDetailPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get levelDetailPlay;

  /// No description provided for @levelDetailNotPlayable.
  ///
  /// In en, this message translates to:
  /// **'This level is still being prepared. Try another one.'**
  String get levelDetailNotPlayable;

  /// No description provided for @levelDetailLockedByProgress.
  ///
  /// In en, this message translates to:
  /// **'Finish the level before this one first.'**
  String get levelDetailLockedByProgress;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get difficultyExpert;

  /// No description provided for @variantTextQa.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get variantTextQa;

  /// No description provided for @variantVerseClue.
  ///
  /// In en, this message translates to:
  /// **'Verse clue'**
  String get variantVerseClue;

  /// No description provided for @variantImageClue.
  ///
  /// In en, this message translates to:
  /// **'Picture clue'**
  String get variantImageClue;

  /// No description provided for @gameplayProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {index} of {total}'**
  String gameplayProgress(int index, int total);

  /// No description provided for @gameplayVersePrompt.
  ///
  /// In en, this message translates to:
  /// **'Which character is this verse about?'**
  String get gameplayVersePrompt;

  /// No description provided for @gameplayImagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Who is this Bible character?'**
  String get gameplayImagePrompt;

  /// No description provided for @gameplayReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read question aloud'**
  String get gameplayReadAloud;

  /// No description provided for @gameplayReadAloudStop.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get gameplayReadAloudStop;

  /// No description provided for @gameplayReadAloudSemantics.
  ///
  /// In en, this message translates to:
  /// **'Read the question aloud'**
  String get gameplayReadAloudSemantics;

  /// No description provided for @gameplayTimerSemantics.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds remaining'**
  String gameplayTimerSemantics(int seconds);

  /// No description provided for @gameplayCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get gameplayCorrect;

  /// No description provided for @gameplayWrong.
  ///
  /// In en, this message translates to:
  /// **'Not this time'**
  String get gameplayWrong;

  /// No description provided for @gameplayLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading this level.'**
  String get gameplayLoadFailed;

  /// No description provided for @gameplayConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — your score won\'t be submitted.'**
  String get gameplayConnectionLost;

  /// No description provided for @gameplayTooFast.
  ///
  /// In en, this message translates to:
  /// **'Take a moment to read the question, then answer.'**
  String get gameplayTooFast;

  /// No description provided for @gameplayAnswerRejected.
  ///
  /// In en, this message translates to:
  /// **'That answer didn\'t register. Please answer again.'**
  String get gameplayAnswerRejected;

  /// No description provided for @gameplayQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this level?'**
  String get gameplayQuitTitle;

  /// No description provided for @gameplayQuitBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress in this level will be lost.'**
  String get gameplayQuitBody;

  /// No description provided for @gameplayQuitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave level'**
  String get gameplayQuitConfirm;

  /// No description provided for @gameplayPracticeBadge.
  ///
  /// In en, this message translates to:
  /// **'Practice mode'**
  String get gameplayPracticeBadge;

  /// No description provided for @levelCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Level complete!'**
  String get levelCompleteTitle;

  /// No description provided for @levelCompleteScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String levelCompleteScore(int score);

  /// No description provided for @levelCompleteAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts: {count}'**
  String levelCompleteAttempts(int count);

  /// No description provided for @levelCompleteNextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get levelCompleteNextLevel;

  /// No description provided for @levelCompleteScoreQueued.
  ///
  /// In en, this message translates to:
  /// **'Score saved — will sync when online.'**
  String get levelCompleteScoreQueued;

  /// No description provided for @levelCompleteNotifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Want a reminder when it\'s time to play again?'**
  String get levelCompleteNotifyTitle;

  /// No description provided for @levelCompleteNotifyBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send one gentle nudge if you haven\'t played in a few days.'**
  String get levelCompleteNotifyBody;

  /// No description provided for @levelCompleteNotifyYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me'**
  String get levelCompleteNotifyYes;

  /// No description provided for @levelCompleteNotifyNo.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get levelCompleteNotifyNo;

  /// No description provided for @levelCompleteNotifyDenied.
  ///
  /// In en, this message translates to:
  /// **'Reminders are switched off for Anointed in your device settings. You can turn them on there.'**
  String get levelCompleteNotifyDenied;

  /// No description provided for @levelFailTitle.
  ///
  /// In en, this message translates to:
  /// **'Great try!'**
  String get levelFailTitle;

  /// No description provided for @levelFailBody.
  ///
  /// In en, this message translates to:
  /// **'Play again to find the answer!'**
  String get levelFailBody;

  /// No description provided for @levelFailAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get levelFailAction;

  /// No description provided for @timerExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up!'**
  String get timerExpiredTitle;

  /// No description provided for @timerExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Give it another go — you\'ll be quicker this time.'**
  String get timerExpiredBody;

  /// No description provided for @adBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'A quick word from our sponsor'**
  String get adBreakTitle;

  /// No description provided for @adBreakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your next level is on the way.'**
  String get adBreakSubtitle;

  /// No description provided for @iapUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock levels {from}–{to}'**
  String iapUnlockTitle(int from, int to);

  /// No description provided for @iapUnlockHeadline.
  ///
  /// In en, this message translates to:
  /// **'Support your child\'s Bible learning'**
  String get iapUnlockHeadline;

  /// No description provided for @iapUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'One payment unlocks every remaining level, forever. Levels 1–5 and Practice mode stay free.'**
  String get iapUnlockBody;

  /// No description provided for @iapUnlockBenefitLevels.
  ///
  /// In en, this message translates to:
  /// **'95 more levels of Bible character challenges'**
  String get iapUnlockBenefitLevels;

  /// No description provided for @iapUnlockBenefitOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time payment — no subscription'**
  String get iapUnlockBenefitOneTime;

  /// No description provided for @iapUnlockBenefitPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice mode always stays free'**
  String get iapUnlockBenefitPractice;

  /// No description provided for @iapUnlockPriceLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking price…'**
  String get iapUnlockPriceLoading;

  /// No description provided for @iapUnlockBuyAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {price}'**
  String iapUnlockBuyAction(String price);

  /// No description provided for @iapUnlockLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get iapUnlockLater;

  /// No description provided for @iapStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is unavailable right now.'**
  String get iapStoreUnavailable;

  /// No description provided for @iapAlreadyPurchasedRestoring.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already purchased this! Restoring your access…'**
  String get iapAlreadyPurchasedRestoring;

  /// No description provided for @purchaseSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get purchaseSuccessTitle;

  /// No description provided for @purchaseSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Levels {from}–{to} are unlocked. Happy playing!'**
  String purchaseSuccessBody(int from, int to);

  /// No description provided for @purchaseSuccessAction.
  ///
  /// In en, this message translates to:
  /// **'Continue playing'**
  String get purchaseSuccessAction;

  /// No description provided for @purchaseFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase didn\'t go through'**
  String get purchaseFailedTitle;

  /// No description provided for @purchaseFailedBody.
  ///
  /// In en, this message translates to:
  /// **'You have not been charged. You can try again, or contact us and we\'ll help.'**
  String get purchaseFailedBody;

  /// No description provided for @purchaseCancelledNotice.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled. Levels 6–100 are still locked.'**
  String get purchaseCancelledNotice;

  /// No description provided for @restorePurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchaseTitle;

  /// No description provided for @restorePurchaseBody.
  ///
  /// In en, this message translates to:
  /// **'If you\'ve already paid, we\'ll restore your access. Make sure you\'re signed in to the store account you paid with.'**
  String get restorePurchaseBody;

  /// No description provided for @restorePurchaseAction.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchaseAction;

  /// No description provided for @restorePurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your purchase has been restored.'**
  String get restorePurchaseSuccess;

  /// No description provided for @restorePurchaseNothing.
  ///
  /// In en, this message translates to:
  /// **'There\'s no previous purchase to restore on this store account.'**
  String get restorePurchaseNothing;

  /// No description provided for @restorePurchaseError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore your purchase. Please try again later.'**
  String get restorePurchaseError;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardWindowAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get leaderboardWindowAllTime;

  /// No description provided for @leaderboardWindowWeekly.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get leaderboardWindowWeekly;

  /// No description provided for @leaderboardWindowDaily.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get leaderboardWindowDaily;

  /// No description provided for @leaderboardColumnRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get leaderboardColumnRank;

  /// No description provided for @leaderboardColumnPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get leaderboardColumnPlayer;

  /// No description provided for @leaderboardColumnScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get leaderboardColumnScore;

  /// No description provided for @leaderboardYourRank.
  ///
  /// In en, this message translates to:
  /// **'Your rank'**
  String get leaderboardYourRank;

  /// No description provided for @leaderboardYourRankValue.
  ///
  /// In en, this message translates to:
  /// **'#{rank} · {score} points'**
  String leaderboardYourRankValue(int rank, int score);

  /// No description provided for @leaderboardYourRankNone.
  ///
  /// In en, this message translates to:
  /// **'Complete a level to join the board.'**
  String get leaderboardYourRankNone;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Be the first! Complete a level to submit your score.'**
  String get leaderboardEmpty;

  /// No description provided for @leaderboardOffline.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard needs internet. Connect to see rankings.'**
  String get leaderboardOffline;

  /// No description provided for @leaderboardError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load leaderboard. Pull down to refresh.'**
  String get leaderboardError;

  /// No description provided for @leaderboardUpdatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes} min ago'**
  String leaderboardUpdatedAgo(int minutes);

  /// No description provided for @leaderboardUpdatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get leaderboardUpdatedJustNow;

  /// No description provided for @leaderboardLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String leaderboardLevelLabel(int number);

  /// No description provided for @practiceHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceHubTitle;

  /// No description provided for @practiceHubSubhead.
  ///
  /// In en, this message translates to:
  /// **'Levels 1–5 offline. No ads, no scores, no internet needed.'**
  String get practiceHubSubhead;

  /// No description provided for @practiceLevelOfflineOnly.
  ///
  /// In en, this message translates to:
  /// **'Offline practice is available for levels 1–5 only.'**
  String get practiceLevelOfflineOnly;

  /// No description provided for @practiceOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get practiceOfflineBadge;

  /// No description provided for @practiceQuestionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Questions updated {date}'**
  String practiceQuestionsUpdated(String date);

  /// No description provided for @practiceUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating practice questions…'**
  String get practiceUpdating;

  /// No description provided for @practiceUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update practice questions. Using saved questions.'**
  String get practiceUpdateFailed;

  /// No description provided for @practiceNoPackOffline.
  ///
  /// In en, this message translates to:
  /// **'Practice questions need a one-time download. Connect to the internet, then open Practice again.'**
  String get practiceNoPackOffline;

  /// No description provided for @practiceNoPackRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry when online'**
  String get practiceNoPackRetry;

  /// No description provided for @practicePackCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Practice questions couldn\'t load. Try reinstalling the app or contact support.'**
  String get practicePackCorrupt;

  /// No description provided for @practiceLevelNotReady.
  ///
  /// In en, this message translates to:
  /// **'This level has no practice questions yet.'**
  String get practiceLevelNotReady;

  /// No description provided for @practiceResultPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get practiceResultPassTitle;

  /// No description provided for @practiceResultPassBody.
  ///
  /// In en, this message translates to:
  /// **'You answered all {count} questions correctly.'**
  String practiceResultPassBody(int count);

  /// No description provided for @practiceResultFailTitle.
  ///
  /// In en, this message translates to:
  /// **'Good practice!'**
  String get practiceResultFailTitle;

  /// No description provided for @practiceResultFailBody.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} of {total} before the level ended.'**
  String practiceResultFailBody(int correct, int total);

  /// No description provided for @practiceResultTryMain.
  ///
  /// In en, this message translates to:
  /// **'Play this level for real'**
  String get practiceResultTryMain;

  /// No description provided for @practiceResultTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice again'**
  String get practiceResultTryAgain;

  /// No description provided for @practiceResultBack.
  ///
  /// In en, this message translates to:
  /// **'Back to practice'**
  String get practiceResultBack;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileStatLevels.
  ///
  /// In en, this message translates to:
  /// **'Levels completed'**
  String get profileStatLevels;

  /// No description provided for @profileStatHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest level'**
  String get profileStatHighest;

  /// No description provided for @profileStatScore.
  ///
  /// In en, this message translates to:
  /// **'Total score'**
  String get profileStatScore;

  /// No description provided for @profilePurchaseUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Levels 6–100 unlocked'**
  String get profilePurchaseUnlocked;

  /// No description provided for @profilePurchaseLocked.
  ///
  /// In en, this message translates to:
  /// **'Levels 6–100 locked'**
  String get profilePurchaseLocked;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Playing since {date}'**
  String profileMemberSince(String date);

  /// No description provided for @profileAgeGroupKid.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get profileAgeGroupKid;

  /// No description provided for @profileAgeGroupYouth.
  ///
  /// In en, this message translates to:
  /// **'Youth'**
  String get profileAgeGroupYouth;

  /// No description provided for @profileAgeGroupAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get profileAgeGroupAdult;

  /// No description provided for @profileAgeGroupElder.
  ///
  /// In en, this message translates to:
  /// **'Elder'**
  String get profileAgeGroupElder;

  /// No description provided for @profileSignedInWith.
  ///
  /// In en, this message translates to:
  /// **'Signed in with {provider}'**
  String profileSignedInWith(String provider);

  /// No description provided for @profileLinkSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileLinkSettings;

  /// No description provided for @profileLinkSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileLinkSupport;

  /// No description provided for @profileLinkDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get profileLinkDelete;

  /// No description provided for @profileRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh profile'**
  String get profileRefreshFailed;

  /// No description provided for @profileUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock all levels'**
  String get profileUnlockAction;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsSectionDisplay;

  /// No description provided for @settingsLargeText.
  ///
  /// In en, this message translates to:
  /// **'Large text'**
  String get settingsLargeText;

  /// No description provided for @settingsLargeTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bigger type across the whole app.'**
  String get settingsLargeTextSubtitle;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsSectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsSectionReminders;

  /// No description provided for @settingsPlayReminders.
  ///
  /// In en, this message translates to:
  /// **'Play reminders'**
  String get settingsPlayReminders;

  /// No description provided for @settingsPlayRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One gentle nudge if you haven\'t played in a few days.'**
  String get settingsPlayRemindersSubtitle;

  /// No description provided for @settingsRemindersBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off for Anointed in your device settings.'**
  String get settingsRemindersBlocked;

  /// No description provided for @settingsOpenDeviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Open device settings'**
  String get settingsOpenDeviceSettings;

  /// No description provided for @settingsSectionPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get settingsSectionPurchases;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Anointed v{version} build {build}'**
  String settingsAppVersion(String version, String build);

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that setting. Please try again.'**
  String get settingsSaveFailed;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to see your progress on this device.'**
  String get signOutBody;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account will permanently remove all your progress, scores, and data. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountChildNote.
  ///
  /// In en, this message translates to:
  /// **'Your child\'s data will be permanently removed from our servers immediately.'**
  String get deleteAccountChildNote;

  /// No description provided for @deleteAccountRemovedHeading.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted'**
  String get deleteAccountRemovedHeading;

  /// No description provided for @deleteAccountRetainedHeading.
  ///
  /// In en, this message translates to:
  /// **'What we keep, with no link to you'**
  String get deleteAccountRetainedHeading;

  /// No description provided for @deleteAccountFirstAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountFirstAction;

  /// No description provided for @deleteAccountFinalTitle.
  ///
  /// In en, this message translates to:
  /// **'One last check'**
  String get deleteAccountFinalTitle;

  /// No description provided for @deleteAccountAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand this is permanent and cannot be undone.'**
  String get deleteAccountAcknowledge;

  /// No description provided for @deleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get deleteAccountConfirmAction;

  /// No description provided for @deleteAccountDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get deleteAccountDoneTitle;

  /// No description provided for @deleteAccountDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for playing Anointed. We\'re returning you to the start.'**
  String get deleteAccountDoneBody;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account right now. Please try again or contact support.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteAccountStatLevels.
  ///
  /// In en, this message translates to:
  /// **'{count} levels completed will be removed'**
  String deleteAccountStatLevels(int count);

  /// No description provided for @deleteAccountPurchaseNote.
  ///
  /// In en, this message translates to:
  /// **'Your purchase cannot be transferred to a new account. Store refunds are handled by Apple or Google.'**
  String get deleteAccountPurchaseNote;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get supportTitle;

  /// No description provided for @supportFaqHeading.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get supportFaqHeading;

  /// No description provided for @supportFaqEmpty.
  ///
  /// In en, this message translates to:
  /// **'No FAQ available right now.'**
  String get supportFaqEmpty;

  /// No description provided for @supportContactHeading.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get supportContactHeading;

  /// No description provided for @supportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s this about?'**
  String get supportCategoryLabel;

  /// No description provided for @supportCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General question'**
  String get supportCategoryGeneral;

  /// No description provided for @supportCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account and sign-in'**
  String get supportCategoryAccount;

  /// No description provided for @supportCategoryPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get supportCategoryPurchase;

  /// No description provided for @supportCategoryGameplay.
  ///
  /// In en, this message translates to:
  /// **'Playing the game'**
  String get supportCategoryGameplay;

  /// No description provided for @supportCategoryPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get supportCategoryPrivacy;

  /// No description provided for @supportMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get supportMessageLabel;

  /// No description provided for @supportMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a little more so we can help.'**
  String get supportMessageRequired;

  /// No description provided for @supportReplyToLabel.
  ///
  /// In en, this message translates to:
  /// **'Email for our reply (optional)'**
  String get supportReplyToLabel;

  /// No description provided for @supportSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get supportSendAction;

  /// No description provided for @supportSendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ve got your message and will reply by email.'**
  String get supportSendSuccess;

  /// No description provided for @supportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message. Try again or email {email} directly.'**
  String supportSendFailed(String email);

  /// No description provided for @supportEmailDirect.
  ///
  /// In en, this message translates to:
  /// **'Email us at {email}'**
  String supportEmailDirect(String email);

  /// No description provided for @supportEmailUsAction.
  ///
  /// In en, this message translates to:
  /// **'Email us instead'**
  String get supportEmailUsAction;

  /// No description provided for @supportContactSubhead.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened and include any details that will help us (your sign-in method, level number, or purchase receipt). We reply by email, usually within one business day.'**
  String get supportContactSubhead;

  /// No description provided for @supportSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'You need to be signed in to read the FAQ or send a message from the app. You can still email us directly.'**
  String get supportSignInRequired;

  /// No description provided for @supportEmailCopyHint.
  ///
  /// In en, this message translates to:
  /// **'No email app found. Write to us at {email}.'**
  String supportEmailCopyHint(String email);

  /// No description provided for @supportVersionNote.
  ///
  /// In en, this message translates to:
  /// **'Include your app version when you contact us — it\'s shown below.'**
  String get supportVersionNote;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Play reminders'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminders to come back and play.'**
  String get notificationChannelDescription;

  /// No description provided for @notification3dTitle.
  ///
  /// In en, this message translates to:
  /// **'Anointed'**
  String get notification3dTitle;

  /// No description provided for @notification3dBody.
  ///
  /// In en, this message translates to:
  /// **'Level {level} is waiting! Come back to Anointed.'**
  String notification3dBody(int level);

  /// No description provided for @notification7dTitle.
  ///
  /// In en, this message translates to:
  /// **'Anointed'**
  String get notification7dTitle;

  /// No description provided for @notification7dBody.
  ///
  /// In en, this message translates to:
  /// **'We miss you! Pick up your Bible character quiz.'**
  String get notification7dBody;

  /// No description provided for @devSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer sign-in'**
  String get devSignInTitle;

  /// No description provided for @devSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Google and Apple sign-in are not configured in this build. Continue with a development account instead.'**
  String get devSignInBody;

  /// No description provided for @devSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Continue as developer account'**
  String get devSignInAction;

  /// No description provided for @devSignInBadge.
  ///
  /// In en, this message translates to:
  /// **'Development build'**
  String get devSignInBadge;

  /// No description provided for @playModeChooserHeading.
  ///
  /// In en, this message translates to:
  /// **'Choose your journey'**
  String get playModeChooserHeading;

  /// No description provided for @playModeMainJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Main Journey'**
  String get playModeMainJourneyTitle;

  /// No description provided for @playModeMainJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'100 levels · leaderboard · ranked play'**
  String get playModeMainJourneySubtitle;

  /// No description provided for @playModeKidsZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Kids Zone'**
  String get playModeKidsZoneTitle;

  /// No description provided for @playModeKidsZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adventure games · stories · stars'**
  String get playModeKidsZoneSubtitle;

  /// No description provided for @kidsZoneHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Kids Zone'**
  String get kidsZoneHubTitle;

  /// No description provided for @kidsZoneHubSubhead.
  ///
  /// In en, this message translates to:
  /// **'Pick an adventure — animated stories, games, and stars!'**
  String get kidsZoneHubSubhead;

  /// No description provided for @kidsZoneBackToMain.
  ///
  /// In en, this message translates to:
  /// **'Back to Main Journey'**
  String get kidsZoneBackToMain;

  /// No description provided for @kidsZoneAdventureStops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String kidsZoneAdventureStops(int count);

  /// No description provided for @kidsZoneStopComplete.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get kidsZoneStopComplete;

  /// No description provided for @kidsZoneStopLocked.
  ///
  /// In en, this message translates to:
  /// **'Finish the stop before this one first'**
  String get kidsZoneStopLocked;

  /// No description provided for @kidsZoneStopPlay.
  ///
  /// In en, this message translates to:
  /// **'Start adventure'**
  String get kidsZoneStopPlay;

  /// No description provided for @kidsZoneStopReplay.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get kidsZoneStopReplay;

  /// No description provided for @kidsZonePackNotReady.
  ///
  /// In en, this message translates to:
  /// **'Adventure questions aren\'t ready yet. Connect to the internet or try again.'**
  String get kidsZonePackNotReady;

  /// No description provided for @kidsZoneWrongFriendly.
  ///
  /// In en, this message translates to:
  /// **'Good try! Tap another answer.'**
  String get kidsZoneWrongFriendly;

  /// No description provided for @kidsZoneCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Adventure complete!'**
  String get kidsZoneCompleteTitle;

  /// No description provided for @kidsZoneCompleteStars.
  ///
  /// In en, this message translates to:
  /// **'You earned {stars} stars!'**
  String kidsZoneCompleteStars(int stars);

  /// No description provided for @kidsZoneCompleteNext.
  ///
  /// In en, this message translates to:
  /// **'Next stop'**
  String get kidsZoneCompleteNext;

  /// No description provided for @kidsZoneCompleteExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore more adventures'**
  String get kidsZoneCompleteExplore;

  /// No description provided for @kidsZoneGameplayHint.
  ///
  /// In en, this message translates to:
  /// **'Take your time — wrong answers let you try again!'**
  String get kidsZoneGameplayHint;

  /// No description provided for @kidsZoneGameStory.
  ///
  /// In en, this message translates to:
  /// **'Story adventure'**
  String get kidsZoneGameStory;

  /// No description provided for @kidsZoneGameListen.
  ///
  /// In en, this message translates to:
  /// **'Listen & learn'**
  String get kidsZoneGameListen;

  /// No description provided for @kidsZoneGameIntro.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get kidsZoneGameIntro;

  /// No description provided for @kidsZoneGameConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect creations'**
  String get kidsZoneGameConnect;

  /// No description provided for @kidsZoneGameJumble.
  ///
  /// In en, this message translates to:
  /// **'Jumbled challenge'**
  String get kidsZoneGameJumble;

  /// No description provided for @kidsZoneGameMatch.
  ///
  /// In en, this message translates to:
  /// **'Match game'**
  String get kidsZoneGameMatch;

  /// No description provided for @kidsZoneGameTrail.
  ///
  /// In en, this message translates to:
  /// **'Story trail'**
  String get kidsZoneGameTrail;

  /// No description provided for @kidsZoneGameExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer hunt'**
  String get kidsZoneGameExplorer;

  /// No description provided for @kidsZoneGameArchery.
  ///
  /// In en, this message translates to:
  /// **'Archery quest'**
  String get kidsZoneGameArchery;

  /// No description provided for @kidsZoneGameArkBuilder.
  ///
  /// In en, this message translates to:
  /// **'Ark builder'**
  String get kidsZoneGameArkBuilder;

  /// No description provided for @kidsZoneGameAnimalMatch.
  ///
  /// In en, this message translates to:
  /// **'Two by two'**
  String get kidsZoneGameAnimalMatch;

  /// No description provided for @kidsZoneGameAnimalCare.
  ///
  /// In en, this message translates to:
  /// **'Animal care'**
  String get kidsZoneGameAnimalCare;

  /// No description provided for @kidsZoneGameFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish adventure'**
  String get kidsZoneGameFinish;

  /// No description provided for @kidsZoneGameMissing.
  ///
  /// In en, this message translates to:
  /// **'This adventure game isn\'t ready yet.'**
  String get kidsZoneGameMissing;

  /// No description provided for @kidsZoneGameMatchProgress.
  ///
  /// In en, this message translates to:
  /// **'Pairs found: {found} of {total}'**
  String kidsZoneGameMatchProgress(int found, int total);

  /// No description provided for @kidsZoneGameTrailHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the stones to put the story in order.'**
  String get kidsZoneGameTrailHint;

  /// No description provided for @kidsZoneGameTrailWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite — try a different order!'**
  String get kidsZoneGameTrailWrong;

  /// No description provided for @kidsZoneGameTrailCheck.
  ///
  /// In en, this message translates to:
  /// **'Check my trail'**
  String get kidsZoneGameTrailCheck;

  /// No description provided for @kidsZoneGameShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle stones'**
  String get kidsZoneGameShuffle;

  /// No description provided for @kidsZoneGameExplorerProgress.
  ///
  /// In en, this message translates to:
  /// **'Found {found} of {total}'**
  String kidsZoneGameExplorerProgress(int found, int total);

  /// No description provided for @kidsZoneListenIntro.
  ///
  /// In en, this message translates to:
  /// **'Listen carefully to the whole story. Questions come after!'**
  String get kidsZoneListenIntro;

  /// No description provided for @kidsZoneListenPart.
  ///
  /// In en, this message translates to:
  /// **'Part {current} of {total}'**
  String kidsZoneListenPart(int current, int total);

  /// No description provided for @kidsZoneListenPlay.
  ///
  /// In en, this message translates to:
  /// **'Listen again'**
  String get kidsZoneListenPlay;

  /// No description provided for @kidsZoneListenPlaying.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get kidsZoneListenPlaying;

  /// No description provided for @kidsZoneListenNext.
  ///
  /// In en, this message translates to:
  /// **'Next part'**
  String get kidsZoneListenNext;

  /// No description provided for @kidsZoneListenReady.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready for questions'**
  String get kidsZoneListenReady;

  /// No description provided for @kidsZoneQuestionIntro.
  ///
  /// In en, this message translates to:
  /// **'Great listening! Now show what you heard.'**
  String get kidsZoneQuestionIntro;

  /// No description provided for @kidsZoneListenWrong.
  ///
  /// In en, this message translates to:
  /// **'Think about the story — try another answer!'**
  String get kidsZoneListenWrong;

  /// No description provided for @kidsZoneIntroSceneHint.
  ///
  /// In en, this message translates to:
  /// **'Listen to the Creation story. Watch the world come alive!'**
  String get kidsZoneIntroSceneHint;

  /// No description provided for @kidsZoneIntroBeginLevel1.
  ///
  /// In en, this message translates to:
  /// **'Start Level 1'**
  String get kidsZoneIntroBeginLevel1;

  /// No description provided for @kidsZoneLevel1Intro.
  ///
  /// In en, this message translates to:
  /// **'Listen to each question, then choose your answer.'**
  String get kidsZoneLevel1Intro;

  /// No description provided for @kidsZoneListenNowListen.
  ///
  /// In en, this message translates to:
  /// **'Listen to the question…'**
  String get kidsZoneListenNowListen;

  /// No description provided for @kidsZoneListenChooseAnswer.
  ///
  /// In en, this message translates to:
  /// **'Now choose your answer'**
  String get kidsZoneListenChooseAnswer;

  /// No description provided for @kidsZoneConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a day, then tap what God made that day. Careful — some things were not made in creation week!'**
  String get kidsZoneConnectHint;

  /// No description provided for @kidsZoneConnectDistractor.
  ///
  /// In en, this message translates to:
  /// **'Some of those were not part of creation week. Look again!'**
  String get kidsZoneConnectDistractor;

  /// No description provided for @kidsZoneConnectWrong.
  ///
  /// In en, this message translates to:
  /// **'Some connections aren\'t right — try again!'**
  String get kidsZoneConnectWrong;

  /// No description provided for @kidsZoneConnectCheck.
  ///
  /// In en, this message translates to:
  /// **'Check my connections'**
  String get kidsZoneConnectCheck;

  /// No description provided for @kidsZoneConnectReset.
  ///
  /// In en, this message translates to:
  /// **'Clear all lines'**
  String get kidsZoneConnectReset;

  /// No description provided for @kidsZoneJumbleProgress.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current} of {total}'**
  String kidsZoneJumbleProgress(int current, int total);

  /// No description provided for @kidsZoneJumbleTapWords.
  ///
  /// In en, this message translates to:
  /// **'Tap the words in order to build the sentence'**
  String get kidsZoneJumbleTapWords;

  /// No description provided for @kidsZoneJumbleHint.
  ///
  /// In en, this message translates to:
  /// **'Try this word next: {word}'**
  String kidsZoneJumbleHint(String word);

  /// No description provided for @kidsZoneJumbleCheck.
  ///
  /// In en, this message translates to:
  /// **'Check sentence'**
  String get kidsZoneJumbleCheck;

  /// No description provided for @kidsZoneJumbleReset.
  ///
  /// In en, this message translates to:
  /// **'Start this sentence over'**
  String get kidsZoneJumbleReset;

  /// No description provided for @kidsZoneJumbleComplete.
  ///
  /// In en, this message translates to:
  /// **'You unscrambled Creation! Rainbow celebration!'**
  String get kidsZoneJumbleComplete;

  /// No description provided for @kidsZoneSiddimIntroHint.
  ///
  /// In en, this message translates to:
  /// **'Hear how Abram bravely rescued Lot in the Valley of Siddim.'**
  String get kidsZoneSiddimIntroHint;

  /// No description provided for @kidsZoneSiddimBeginLevel1.
  ///
  /// In en, this message translates to:
  /// **'Start the archery quest'**
  String get kidsZoneSiddimBeginLevel1;

  /// No description provided for @kidsZoneSiddimAimHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to aim · let go to shoot · keep soldiers out of the camp'**
  String get kidsZoneSiddimAimHint;

  /// No description provided for @kidsZoneSiddimRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String kidsZoneSiddimRoundLabel(int round, int total);

  /// No description provided for @kidsZoneSiddimCourageLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 courage heart left} other{{count} courage hearts left}}'**
  String kidsZoneSiddimCourageLeft(int count);

  /// No description provided for @kidsZoneSiddimRoundCleared.
  ///
  /// In en, this message translates to:
  /// **'Round cleared!'**
  String get kidsZoneSiddimRoundCleared;

  /// No description provided for @kidsZoneSiddimRoundStats.
  ///
  /// In en, this message translates to:
  /// **'{score} points · {accuracy}% accuracy'**
  String kidsZoneSiddimRoundStats(int score, int accuracy);

  /// No description provided for @kidsZoneSiddimVictoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Abram wins the day!'**
  String get kidsZoneSiddimVictoryTitle;

  /// No description provided for @kidsZoneSiddimVictoryBody.
  ///
  /// In en, this message translates to:
  /// **'King Chedorlaomer turns back and Lot comes home safe.'**
  String get kidsZoneSiddimVictoryBody;

  /// No description provided for @kidsZoneSiddimBreached.
  ///
  /// In en, this message translates to:
  /// **'The soldiers reached the camp'**
  String get kidsZoneSiddimBreached;

  /// No description provided for @kidsZoneSiddimBreachedBody.
  ///
  /// In en, this message translates to:
  /// **'Abram never gave up — and neither should you. Try this round again!'**
  String get kidsZoneSiddimBreachedBody;

  /// No description provided for @kidsZoneSiddimTryRoundAgain.
  ///
  /// In en, this message translates to:
  /// **'Try this round again'**
  String get kidsZoneSiddimTryRoundAgain;

  /// No description provided for @kidsZoneSiddimNearMiss.
  ///
  /// In en, this message translates to:
  /// **'Almost!'**
  String get kidsZoneSiddimNearMiss;

  /// No description provided for @kidsZoneSiddimAimHintAccessible.
  ///
  /// In en, this message translates to:
  /// **'Choose a lane to shoot along'**
  String get kidsZoneSiddimAimHintAccessible;

  /// No description provided for @kidsZoneSiddimStatTurnedBack.
  ///
  /// In en, this message translates to:
  /// **'Soldiers turned back'**
  String get kidsZoneSiddimStatTurnedBack;

  /// No description provided for @kidsZoneSiddimStatArrows.
  ///
  /// In en, this message translates to:
  /// **'Arrows on target'**
  String get kidsZoneSiddimStatArrows;

  /// No description provided for @kidsZoneSiddimStatHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts left'**
  String get kidsZoneSiddimStatHearts;

  /// No description provided for @kidsZoneSiddimStatPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get kidsZoneSiddimStatPoints;

  /// No description provided for @kidsZoneSiddimGoalNoBreach.
  ///
  /// In en, this message translates to:
  /// **'Let nobody reach the camp'**
  String get kidsZoneSiddimGoalNoBreach;

  /// No description provided for @kidsZoneSiddimGoalAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Hit with {percent}% of your arrows'**
  String kidsZoneSiddimGoalAccuracy(int percent);

  /// No description provided for @kidsZoneSiddimLaneFarLeft.
  ///
  /// In en, this message translates to:
  /// **'far left'**
  String get kidsZoneSiddimLaneFarLeft;

  /// No description provided for @kidsZoneSiddimLaneLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get kidsZoneSiddimLaneLeft;

  /// No description provided for @kidsZoneSiddimLaneAhead.
  ///
  /// In en, this message translates to:
  /// **'straight ahead'**
  String get kidsZoneSiddimLaneAhead;

  /// No description provided for @kidsZoneSiddimLaneRight.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get kidsZoneSiddimLaneRight;

  /// No description provided for @kidsZoneSiddimLaneFarRight.
  ///
  /// In en, this message translates to:
  /// **'far right'**
  String get kidsZoneSiddimLaneFarRight;

  /// No description provided for @kidsZoneSiddimFireLane.
  ///
  /// In en, this message translates to:
  /// **'Shoot {lane}'**
  String kidsZoneSiddimFireLane(String lane);

  /// No description provided for @kidsZoneSiddimThreatNone.
  ///
  /// In en, this message translates to:
  /// **'The valley is clear'**
  String get kidsZoneSiddimThreatNone;

  /// No description provided for @kidsZoneSiddimThreatAt.
  ///
  /// In en, this message translates to:
  /// **'Nearest soldier: {lane}'**
  String kidsZoneSiddimThreatAt(String lane);

  /// No description provided for @kidsZoneArkIntroHint.
  ///
  /// In en, this message translates to:
  /// **'Hear how Noah trusted God, built the ark, and kept every animal safe.'**
  String get kidsZoneArkIntroHint;

  /// No description provided for @kidsZoneArkBeginLevel1.
  ///
  /// In en, this message translates to:
  /// **'Start building the ark'**
  String get kidsZoneArkBeginLevel1;

  /// No description provided for @kidsZoneArkStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} of {total}'**
  String kidsZoneArkStageLabel(int stage, int total);

  /// No description provided for @kidsZoneArkPiecePlaced.
  ///
  /// In en, this message translates to:
  /// **'{piece} fitted'**
  String kidsZoneArkPiecePlaced(String piece);

  /// No description provided for @kidsZoneArkTrayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every piece is in place!'**
  String get kidsZoneArkTrayEmpty;

  /// No description provided for @kidsZoneArkStageDone.
  ///
  /// In en, this message translates to:
  /// **'Stage complete!'**
  String get kidsZoneArkStageDone;

  /// No description provided for @kidsZoneArkStageNext.
  ///
  /// In en, this message translates to:
  /// **'Noah kept working day after day. Let\'s keep going!'**
  String get kidsZoneArkStageNext;

  /// No description provided for @kidsZoneArkKeepBuilding.
  ///
  /// In en, this message translates to:
  /// **'Keep building'**
  String get kidsZoneArkKeepBuilding;

  /// No description provided for @kidsZoneArkBuiltTitle.
  ///
  /// In en, this message translates to:
  /// **'The ark is finished!'**
  String get kidsZoneArkBuiltTitle;

  /// No description provided for @kidsZoneArkBuiltBody.
  ///
  /// In en, this message translates to:
  /// **'Noah obeyed God and finished every plank. Well done!'**
  String get kidsZoneArkBuiltBody;

  /// No description provided for @kidsZoneArkMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Flip two cards to find each animal and its mate. You have 5 hearts!'**
  String get kidsZoneArkMatchHint;

  /// No description provided for @kidsZoneArkPairsFound.
  ///
  /// In en, this message translates to:
  /// **'Pairs: {found} of {total}'**
  String kidsZoneArkPairsFound(int found, int total);

  /// No description provided for @kidsZoneArkLivesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 heart left} other{{count} hearts left}}'**
  String kidsZoneArkLivesLeft(int count);

  /// No description provided for @kidsZoneArkPairFound.
  ///
  /// In en, this message translates to:
  /// **'{animal} pair found'**
  String kidsZoneArkPairFound(String animal);

  /// No description provided for @kidsZoneArkMatchWonTitle.
  ///
  /// In en, this message translates to:
  /// **'Every animal is aboard!'**
  String get kidsZoneArkMatchWonTitle;

  /// No description provided for @kidsZoneArkMatchWonBody.
  ///
  /// In en, this message translates to:
  /// **'Two by two, just as God told Noah.'**
  String get kidsZoneArkMatchWonBody;

  /// No description provided for @kidsZoneArkMatchLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of hearts'**
  String get kidsZoneArkMatchLostTitle;

  /// No description provided for @kidsZoneArkMatchLostBody.
  ///
  /// In en, this message translates to:
  /// **'Noah never gave up. Shall we try once more?'**
  String get kidsZoneArkMatchLostBody;

  /// No description provided for @kidsZoneArkTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get kidsZoneArkTryAgain;

  /// No description provided for @kidsZoneArkPracticeMode.
  ///
  /// In en, this message translates to:
  /// **'Practice mode: unlimited hearts'**
  String get kidsZoneArkPracticeMode;

  /// No description provided for @kidsZoneArkHeartsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited hearts'**
  String get kidsZoneArkHeartsUnlimited;

  /// No description provided for @kidsZoneArkMercyReveal.
  ///
  /// In en, this message translates to:
  /// **'Here they are! Remember where they go.'**
  String get kidsZoneArkMercyReveal;

  /// No description provided for @kidsZoneArkPracticeStar.
  ///
  /// In en, this message translates to:
  /// **'Practice run — play with hearts to earn more stars.'**
  String get kidsZoneArkPracticeStar;

  /// No description provided for @kidsZoneArkRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String kidsZoneArkRoundLabel(int round, int total);

  /// No description provided for @kidsZoneArkTasks.
  ///
  /// In en, this message translates to:
  /// **'Cared for {done} of {total}'**
  String kidsZoneArkTasks(int done, int total);

  /// No description provided for @kidsZoneArkHappiness.
  ///
  /// In en, this message translates to:
  /// **'Animals are {percent}% happy'**
  String kidsZoneArkHappiness(int percent);

  /// No description provided for @kidsZoneArkToolFood.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get kidsZoneArkToolFood;

  /// No description provided for @kidsZoneArkToolWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get kidsZoneArkToolWater;

  /// No description provided for @kidsZoneArkToolClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get kidsZoneArkToolClean;

  /// No description provided for @kidsZoneArkToolComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get kidsZoneArkToolComfort;

  /// No description provided for @kidsZoneArkPickToolFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a tool first, then tap the animal.'**
  String get kidsZoneArkPickToolFirst;

  /// No description provided for @kidsZoneArkCared.
  ///
  /// In en, this message translates to:
  /// **'{animal} is happy'**
  String kidsZoneArkCared(String animal);

  /// No description provided for @kidsZoneArkRoundDone.
  ///
  /// In en, this message translates to:
  /// **'Round complete!'**
  String get kidsZoneArkRoundDone;

  /// No description provided for @kidsZoneArkNextRound.
  ///
  /// In en, this message translates to:
  /// **'Next round'**
  String get kidsZoneArkNextRound;

  /// No description provided for @kidsZoneArkCareDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'A safe voyage!'**
  String get kidsZoneArkCareDoneTitle;

  /// No description provided for @kidsZoneArkCareDoneBody.
  ///
  /// In en, this message translates to:
  /// **'You cared for every animal until the waters went down.'**
  String get kidsZoneArkCareDoneBody;

  /// No description provided for @kidsZoneArkTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'How to help the animals'**
  String get kidsZoneArkTutorialTitle;

  /// No description provided for @kidsZoneArkTutorialBody.
  ///
  /// In en, this message translates to:
  /// **'An animal shows a picture of what it needs. Pick the matching tool, then tap that animal.'**
  String get kidsZoneArkTutorialBody;

  /// No description provided for @kidsZoneArkTutorialStart.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready!'**
  String get kidsZoneArkTutorialStart;

  /// No description provided for @kidsZoneArkTutorialHelp.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get kidsZoneArkTutorialHelp;

  /// No description provided for @kidsZoneGameRiverRescue.
  ///
  /// In en, this message translates to:
  /// **'River rescue'**
  String get kidsZoneGameRiverRescue;

  /// No description provided for @kidsZoneMosesIntroHint.
  ///
  /// In en, this message translates to:
  /// **'Listen to the story of baby Moses on the river.'**
  String get kidsZoneMosesIntroHint;

  /// No description provided for @kidsZoneMosesBeginLevel1.
  ///
  /// In en, this message translates to:
  /// **'Begin Level 1'**
  String get kidsZoneMosesBeginLevel1;

  /// No description provided for @kidsZoneGamePlagueSort.
  ///
  /// In en, this message translates to:
  /// **'Plagues of Egypt'**
  String get kidsZoneGamePlagueSort;

  /// No description provided for @kidsZoneGameSeaCrossing.
  ///
  /// In en, this message translates to:
  /// **'Crossing the sea'**
  String get kidsZoneGameSeaCrossing;

  /// No description provided for @kidsZoneSeaPhaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Part {phase} of {total}'**
  String kidsZoneSeaPhaseLabel(int phase, int total);

  /// No description provided for @kidsZoneSeaBeatsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{hits} of {total} beats kept'**
  String kidsZoneSeaBeatsSemantics(int hits, int total);

  /// No description provided for @kidsZonePlagueRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String kidsZonePlagueRoundLabel(int round, int total);

  /// No description provided for @kidsZonePlagueStep.
  ///
  /// In en, this message translates to:
  /// **'{step}'**
  String kidsZonePlagueStep(int step);

  /// No description provided for @kidsZonePlagueResolveLabel.
  ///
  /// In en, this message translates to:
  /// **'Pharaoh\'s heart'**
  String get kidsZonePlagueResolveLabel;

  /// No description provided for @kidsZonePlagueResolveBroken.
  ///
  /// In en, this message translates to:
  /// **'Pharaoh lets them go!'**
  String get kidsZonePlagueResolveBroken;

  /// No description provided for @kidsZonePlagueResolveSemantics.
  ///
  /// In en, this message translates to:
  /// **'Pharaoh\'s heart: {cracks} of {total} cracks'**
  String kidsZonePlagueResolveSemantics(int cracks, int total);

  /// No description provided for @kidsZonePlagueCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}. Drag onto the right step.'**
  String kidsZonePlagueCardSemantics(String name);

  /// No description provided for @kidsZonePlagueHearSemantics.
  ///
  /// In en, this message translates to:
  /// **'Hear about {name}'**
  String kidsZonePlagueHearSemantics(String name);

  /// No description provided for @kidsZonePlaguePlaced.
  ///
  /// In en, this message translates to:
  /// **'{name} is in the right place'**
  String kidsZonePlaguePlaced(String name);

  /// No description provided for @kidsZonePlaguePreviewToggle.
  ///
  /// In en, this message translates to:
  /// **'Watch it once first'**
  String get kidsZonePlaguePreviewToggle;

  /// No description provided for @kidsZonePlagueStart.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get kidsZonePlagueStart;

  /// No description provided for @kidsZonePlagueRoundDone.
  ///
  /// In en, this message translates to:
  /// **'Pharaoh\'s heart cracks!'**
  String get kidsZonePlagueRoundDone;

  /// No description provided for @kidsZonePlagueRoundDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total} is done. Egypt has not seen the last of this.'**
  String kidsZonePlagueRoundDoneBody(int round, int total);

  /// No description provided for @kidsZonePlagueNextRound.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get kidsZonePlagueNextRound;

  /// No description provided for @kidsZonePlagueDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Let my people go'**
  String get kidsZonePlagueDoneTitle;

  /// No description provided for @kidsZonePlagueDoneBody.
  ///
  /// In en, this message translates to:
  /// **'The crown has fallen. Pharaoh finally lets God\'s people leave Egypt.'**
  String get kidsZonePlagueDoneBody;

  /// No description provided for @kidsZonePlagueCollectStars.
  ///
  /// In en, this message translates to:
  /// **'Collect my stars'**
  String get kidsZonePlagueCollectStars;

  /// No description provided for @kidsZonePlagueSayBlood.
  ///
  /// In en, this message translates to:
  /// **'I stretched out my staff, and the Nile turned to blood.'**
  String get kidsZonePlagueSayBlood;

  /// No description provided for @kidsZonePlagueSayFrogs.
  ///
  /// In en, this message translates to:
  /// **'Then frogs came up out of the river, into every house in Egypt.'**
  String get kidsZonePlagueSayFrogs;

  /// No description provided for @kidsZonePlagueSayGnats.
  ///
  /// In en, this message translates to:
  /// **'The dust of the ground became gnats, all over the land.'**
  String get kidsZonePlagueSayGnats;

  /// No description provided for @kidsZonePlagueSayFlies.
  ///
  /// In en, this message translates to:
  /// **'Great swarms of flies filled Pharaoh\'s palace.'**
  String get kidsZonePlagueSayFlies;

  /// No description provided for @kidsZonePlagueSayLivestock.
  ///
  /// In en, this message translates to:
  /// **'The animals in the fields grew sick, but not one of ours.'**
  String get kidsZonePlagueSayLivestock;

  /// No description provided for @kidsZonePlagueSayBoils.
  ///
  /// In en, this message translates to:
  /// **'Sores broke out on the people of Egypt, and Pharaoh still said no.'**
  String get kidsZonePlagueSayBoils;

  /// No description provided for @kidsZonePlagueSayHail.
  ///
  /// In en, this message translates to:
  /// **'Hail and fire fell together out of the sky.'**
  String get kidsZonePlagueSayHail;

  /// No description provided for @kidsZonePlagueSayLocusts.
  ///
  /// In en, this message translates to:
  /// **'Locusts came in a cloud and ate every green thing left.'**
  String get kidsZonePlagueSayLocusts;

  /// No description provided for @kidsZonePlagueSayDarkness.
  ///
  /// In en, this message translates to:
  /// **'Darkness covered Egypt for three days, so thick you could feel it.'**
  String get kidsZonePlagueSayDarkness;

  /// No description provided for @kidsZonePlagueSayFirstborn.
  ///
  /// In en, this message translates to:
  /// **'After the last night, Pharaoh\'s crown fell, and he let my people go.'**
  String get kidsZonePlagueSayFirstborn;

  /// No description provided for @kidsZoneRiverStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} of {total}'**
  String kidsZoneRiverStageLabel(int stage, int total);

  /// No description provided for @kidsZoneRiverDistance.
  ///
  /// In en, this message translates to:
  /// **'{metres} metres travelled'**
  String kidsZoneRiverDistance(int metres);

  /// No description provided for @kidsZoneRiverExit.
  ///
  /// In en, this message translates to:
  /// **'Leave River Rescue'**
  String get kidsZoneRiverExit;

  /// No description provided for @kidsZoneRiverBumpToast.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{A splash! No hearts left, but keep floating!} =1{A splash! One heart left — you can do it!} other{A splash! {count} hearts left — try again!}}'**
  String kidsZoneRiverBumpToast(int count);

  /// No description provided for @kidsZoneRiverFreshChanceToast.
  ///
  /// In en, this message translates to:
  /// **'Fresh hearts — a new chance for this stretch!'**
  String get kidsZoneRiverFreshChanceToast;

  /// No description provided for @kidsZoneRiverHeartsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 heart left} other{{count} hearts left}}'**
  String kidsZoneRiverHeartsLeft(int count);

  /// No description provided for @kidsZoneRiverLotusCount.
  ///
  /// In en, this message translates to:
  /// **'{collected} of {total} lotus flowers'**
  String kidsZoneRiverLotusCount(int collected, int total);

  /// No description provided for @kidsZoneRiverLaneLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get kidsZoneRiverLaneLeft;

  /// No description provided for @kidsZoneRiverLaneCenter.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get kidsZoneRiverLaneCenter;

  /// No description provided for @kidsZoneRiverLaneRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get kidsZoneRiverLaneRight;

  /// No description provided for @kidsZoneRiverHop.
  ///
  /// In en, this message translates to:
  /// **'Hop'**
  String get kidsZoneRiverHop;

  /// No description provided for @kidsZoneRiverDuck.
  ///
  /// In en, this message translates to:
  /// **'Duck'**
  String get kidsZoneRiverDuck;

  /// No description provided for @kidsZoneRiverBoost.
  ///
  /// In en, this message translates to:
  /// **'Paddle'**
  String get kidsZoneRiverBoost;

  /// No description provided for @kidsZoneRiverShielded.
  ///
  /// In en, this message translates to:
  /// **'An angel is watching over you'**
  String get kidsZoneRiverShielded;

  /// No description provided for @kidsZoneRiverBoosting.
  ///
  /// In en, this message translates to:
  /// **'Paddling fast!'**
  String get kidsZoneRiverBoosting;

  /// No description provided for @kidsZoneRiverBlessingTaken.
  ///
  /// In en, this message translates to:
  /// **'An angel blessing! You are safe for a moment.'**
  String get kidsZoneRiverBlessingTaken;

  /// No description provided for @kidsZoneRiverStageDone.
  ///
  /// In en, this message translates to:
  /// **'You made it!'**
  String get kidsZoneRiverStageDone;

  /// No description provided for @kidsZoneRiverStageDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} of {total} is behind you. The river runs faster ahead.'**
  String kidsZoneRiverStageDoneBody(int stage, int total);

  /// No description provided for @kidsZoneRiverNextStage.
  ///
  /// In en, this message translates to:
  /// **'Keep floating'**
  String get kidsZoneRiverNextStage;

  /// No description provided for @kidsZoneRiverDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe in the princess\'s arms'**
  String get kidsZoneRiverDoneTitle;

  /// No description provided for @kidsZoneRiverDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Baby Moses floated all the way down the Nile, and the princess lifted him out of the water.'**
  String get kidsZoneRiverDoneBody;

  /// No description provided for @kidsZoneRiverCollectStars.
  ///
  /// In en, this message translates to:
  /// **'Collect my stars'**
  String get kidsZoneRiverCollectStars;

  /// Kids Zone adventure creation_garden: name
  ///
  /// In en, this message translates to:
  /// **'Creation Garden'**
  String get kidsZoneAdventureCreationGardenTitle;

  /// Kids Zone adventure creation_garden: one-line description
  ///
  /// In en, this message translates to:
  /// **'Genesis — listen, learn, and play'**
  String get kidsZoneAdventureCreationGardenSubtitle;

  /// Kids Zone adventure battle_of_siddim: name
  ///
  /// In en, this message translates to:
  /// **'Battle of Siddim'**
  String get kidsZoneAdventureBattleOfSiddimTitle;

  /// Kids Zone adventure battle_of_siddim: one-line description
  ///
  /// In en, this message translates to:
  /// **'Genesis 14 — Abraham\'s archery quest'**
  String get kidsZoneAdventureBattleOfSiddimSubtitle;

  /// Kids Zone adventure noahs_ark: name
  ///
  /// In en, this message translates to:
  /// **'Noah\'s Ark'**
  String get kidsZoneAdventureNoahsArkTitle;

  /// Kids Zone adventure noahs_ark: one-line description
  ///
  /// In en, this message translates to:
  /// **'Genesis 6-9 — a faithful journey'**
  String get kidsZoneAdventureNoahsArkSubtitle;

  /// Kids Zone adventure moses_nile: name
  ///
  /// In en, this message translates to:
  /// **'Baby Moses'**
  String get kidsZoneAdventureMosesNileTitle;

  /// Kids Zone adventure moses_nile: one-line description
  ///
  /// In en, this message translates to:
  /// **'Exodus 1-2 - down the river to the princess'**
  String get kidsZoneAdventureMosesNileSubtitle;

  /// Kids Zone adventure heroes_path: name
  ///
  /// In en, this message translates to:
  /// **'Heroes Path'**
  String get kidsZoneAdventureHeroesPathTitle;

  /// Kids Zone adventure heroes_path: one-line description
  ///
  /// In en, this message translates to:
  /// **'Coming soon — more Bible adventures'**
  String get kidsZoneAdventureHeroesPathSubtitle;

  /// Kids Zone adventure wise_kings: name
  ///
  /// In en, this message translates to:
  /// **'Wise Kings'**
  String get kidsZoneAdventureWiseKingsTitle;

  /// Kids Zone adventure wise_kings: one-line description
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get kidsZoneAdventureWiseKingsSubtitle;

  /// Kids Zone stop creation_intro: name
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get kidsZoneStopCreationIntroTitle;

  /// Kids Zone stop creation_intro: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Animated story — day by day'**
  String get kidsZoneStopCreationIntroTeaser;

  /// Kids Zone stop garden_1: name
  ///
  /// In en, this message translates to:
  /// **'Level 1 — God\'s Questions'**
  String get kidsZoneStopGarden1Title;

  /// Kids Zone stop garden_1: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Listen & answer about Creation'**
  String get kidsZoneStopGarden1Teaser;

  /// Kids Zone stop garden_2: name
  ///
  /// In en, this message translates to:
  /// **'Level 2 — Connect Creations'**
  String get kidsZoneStopGarden2Title;

  /// Kids Zone stop garden_2: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Match days to what God made'**
  String get kidsZoneStopGarden2Teaser;

  /// Kids Zone stop garden_3: name
  ///
  /// In en, this message translates to:
  /// **'Level 3 — Jumbled Challenge'**
  String get kidsZoneStopGarden3Title;

  /// Kids Zone stop garden_3: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Unscramble creation sentences'**
  String get kidsZoneStopGarden3Teaser;

  /// Kids Zone stop siddim_intro: name
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get kidsZoneStopSiddimIntroTitle;

  /// Kids Zone stop siddim_intro: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'The valley, the four kings, and Lot'**
  String get kidsZoneStopSiddimIntroTeaser;

  /// Kids Zone stop siddim_1: name
  ///
  /// In en, this message translates to:
  /// **'Level 1 — Defend the Valley'**
  String get kidsZoneStopSiddim1Title;

  /// Kids Zone stop siddim_1: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Rounds 1-2 — learn to aim and shoot'**
  String get kidsZoneStopSiddim1Teaser;

  /// Kids Zone stop siddim_2: name
  ///
  /// In en, this message translates to:
  /// **'Level 2 — The Night Rescue'**
  String get kidsZoneStopSiddim2Title;

  /// Kids Zone stop siddim_2: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Rounds 3-5 — faster, trickier soldiers'**
  String get kidsZoneStopSiddim2Teaser;

  /// Kids Zone stop siddim_3: name
  ///
  /// In en, this message translates to:
  /// **'Level 3 — King\'s Round'**
  String get kidsZoneStopSiddim3Title;

  /// Kids Zone stop siddim_3: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Round 6 — King Chedorlaomer himself'**
  String get kidsZoneStopSiddim3Teaser;

  /// Kids Zone stop ark_intro: name
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get kidsZoneStopArkIntroTitle;

  /// Kids Zone stop ark_intro: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Noah, the ark, and God\'s promise'**
  String get kidsZoneStopArkIntroTeaser;

  /// Kids Zone stop ark_1: name
  ///
  /// In en, this message translates to:
  /// **'Level 1 — Ark Builder'**
  String get kidsZoneStopArk1Title;

  /// Kids Zone stop ark_1: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Drag the timber into place'**
  String get kidsZoneStopArk1Teaser;

  /// Kids Zone stop ark_2: name
  ///
  /// In en, this message translates to:
  /// **'Level 2 — Two by Two'**
  String get kidsZoneStopArk2Title;

  /// Kids Zone stop ark_2: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Memory match — find each animal\'s mate'**
  String get kidsZoneStopArk2Teaser;

  /// Kids Zone stop ark_3: name
  ///
  /// In en, this message translates to:
  /// **'Level 3 — Animal Care'**
  String get kidsZoneStopArk3Title;

  /// Kids Zone stop ark_3: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Feed, clean and comfort the animals'**
  String get kidsZoneStopArk3Teaser;

  /// Kids Zone stop moses_intro: name
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get kidsZoneStopMosesIntroTitle;

  /// Kids Zone stop moses_intro: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Pharaoh, a basket of reeds, and a princess'**
  String get kidsZoneStopMosesIntroTeaser;

  /// Kids Zone stop moses_1: name
  ///
  /// In en, this message translates to:
  /// **'Level 1 - River Rescue'**
  String get kidsZoneStopMoses1Title;

  /// Kids Zone stop moses_1: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Steer the basket past reeds, logs and sleepy crocodiles'**
  String get kidsZoneStopMoses1Teaser;

  /// Kids Zone stop moses_2: name
  ///
  /// In en, this message translates to:
  /// **'Level 2 - Plagues of Egypt'**
  String get kidsZoneStopMoses2Title;

  /// Kids Zone stop moses_2: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Put the ten plagues in order and watch Egypt answer'**
  String get kidsZoneStopMoses2Teaser;

  /// Kids Zone stop moses_3: name
  ///
  /// In en, this message translates to:
  /// **'Level 3 - Crossing the Sea'**
  String get kidsZoneStopMoses3Title;

  /// Kids Zone stop moses_3: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Part the water, walk across, and send the chariots home'**
  String get kidsZoneStopMoses3Teaser;

  /// Kids Zone stop heroes_2: name
  ///
  /// In en, this message translates to:
  /// **'Young David'**
  String get kidsZoneStopHeroes2Title;

  /// Kids Zone stop heroes_2: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Explore the pasture'**
  String get kidsZoneStopHeroes2Teaser;

  /// Kids Zone stop kings_1: name
  ///
  /// In en, this message translates to:
  /// **'Solomon\'s Gift'**
  String get kidsZoneStopKings1Title;

  /// Kids Zone stop kings_1: one-line teaser
  ///
  /// In en, this message translates to:
  /// **'Story adventure'**
  String get kidsZoneStopKings1Teaser;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
