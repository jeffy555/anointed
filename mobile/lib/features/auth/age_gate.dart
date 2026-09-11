import 'package:flutter/widgets.dart';

import '../../core/routes.dart';
import '../../models/session.dart';

/// M-05 — the age gate.
///
/// design-spec §1B describes M-05 as "silent routing after profile capture"
/// rather than a screen, and design-spec §3 puts the decision on the server so a
/// client cannot skip the VPC flow by not navigating to it. This file is
/// therefore the whole of M-05 on the client: a pure mapping from the server's
/// `next_step` to a destination route, with no local age arithmetic anywhere.
///
/// Age < 13 surfaces as `parental_consent` and routes into the M-06 series;
/// age >= 13 surfaces as `privacy_acknowledgment` and routes to M-08.
String routeForStep(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.profileCompletion:
      return Routes.profileCompletion;
    case OnboardingStep.parentalConsent:
      return Routes.parentGate;
    case OnboardingStep.childPrivacyNotice:
      return Routes.childNotice;
    case OnboardingStep.privacyAcknowledgment:
      return Routes.privacyTerms;
    case OnboardingStep.levelMap:
      return Routes.home;
  }
}

/// Replaces the whole stack with the step's destination.
///
/// Onboarding is a forward-only sequence — there is no "back" out of the parent
/// gate (design-spec §11 UX rule 1: M-06 is a hard block, no skip) — so every
/// transition clears history rather than pushing.
void goToStep(BuildContext context, OnboardingStep step, {Object? arguments}) {
  Navigator.of(context).pushNamedAndRemoveUntil(
    routeForStep(step),
    (Route<dynamic> route) => false,
    arguments: arguments,
  );
}
