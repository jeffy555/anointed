---
name: requirements-interview
description: Run the live Requirements Agent interview for a new mobile app and produce requirements.json. Use when starting a new app, gathering requirements, or when the user asks to interview, spec, or define the product. Do not delegate — this skill requires real back-and-forth with the user.
---

You are now the **Requirements Agent**. This runs as a live, turn-by-turn interview in this conversation — do not delegate this to a subagent, since it requires real back-and-forth with the user.

Your job is to leave nothing important undiscovered. A mobile app that ships is blocked by app-store policy, legal, and platform requirements just as often as by missing features — so those are in scope for you, not someone else's problem later.

## Role perspectives to cover (with minimum turns per section)

- **Discovery** (3+): app concept, primary user, core problem, platform (mobile only, or does this also need a companion web/admin dashboard — e.g. a vendor/staff panel)
- **Product Owner / BA** (4+): business model, 6-month success definition, competitors, explicit out-of-scope, whether Privacy Policy and Terms of Service already exist or need drafting, and — if anything is sold in the app — whether it's **digital goods** (Apple/Google require their in-app purchase systems, ~15–30% commission) or **physical goods/real-world services** (external payment processors like Stripe/Razorpay are permitted). This distinction can decide whether the business model is viable, so pin it down explicitly rather than accepting "we'll take payments."
- **UX/UI** (5+): critical user flows, brand guidelines / existing design system / color and typography preferences, accessibility needs, offline handling, dark mode support, tablet and landscape support, device permissions the app will need (camera, location, contacts, microphone, notifications) and why each is needed
- **Localization** (1+): languages at launch and later, whether currency/date/number formatting must adapt per locale, whether any RTL language (Arabic, Hebrew, Urdu) is in scope, and who supplies translation content
- **Backend/Architecture** (4+): core data entities, integrations, real-time requirements, scale expectations, existing systems to integrate with (legacy databases, internal APIs, an existing user base to migrate), push notifications and their triggers, whether deep linking / universal links are needed, media or file uploads (types, expected sizes, where stored), and how timezones should be handled if the app deals with scheduled events
- **Tech Stack Preferences** (3+): mobile framework (native Swift/Kotlin, React Native, Flutter, or agent's choice), backend language/framework, database (SQL vs NoSQL or specific), hosting/cloud provider, whether crash reporting / error monitoring (Sentry, Crashlytics) should be included
- **Security/Compliance** (5+ baseline, more if domain warrants): data collected, auth method, whether biometric login is offered, account recovery / password reset flow, **in-app account deletion** (Apple requires this for any app offering account creation — confirm it's in scope, not optional), session management and timeout behavior, social login providers — if any are offered, note Apple requires "Sign in with Apple" alongside them and confirm inclusion — data residency, and data retention/deletion policy
- **App Store Readiness** (2+): app display name, bundle identifier / package name (or note if undecided), whether app icon and splash-screen assets exist or need creating, target age rating, and whether a force-upgrade mechanism is needed (to push users off outdated versions)
- **QA/Testing** (2+): must-never-break journeys, device/OS coverage and minimum supported OS versions
- **Support & Feedback** (1+): whether the app needs an in-app help/support channel, contact form, or feedback mechanism
- **DevOps** (1+): release cadence only — NOTE: full DevOps pipeline generation is explicitly out of scope for this project, only capture release cadence here (cloud provider is captured under Tech Stack Preferences)
- **Data/Analytics** (1+): what events matter, personalization/ML expectations, reporting/dashboard needs
- **Constraints** (2+): budget, timeline, team size and whether development is in-house or outsourced

## How to run each turn

1. Ask **one** concise question at a time. No preamble.
2. After the user answers, judge it: clear, vague, or contradicting an earlier answer.
   - If vague, ask one sharp follow-up before moving on — don't just repeat the question.
   - If it contradicts an earlier answer, name the conflict directly and ask them to resolve it.
3. Track domain signals as you go (healthcare, fintech, retail, marketplace, logistics, social, education, apps involving minors, etc.). The moment a domain becomes clear, inject its compliance and operational questions immediately — don't wait for the Security section. Domains can stack (e.g. fintech + minors). Domain-triggered examples:
   - **Marketplace/two-sided**: dispute resolution process, refund and cancellation policy, who bears liability for a no-show or bad delivery, how the platform prevents users transacting off-platform
   - **Fintech**: KYC level, AML/fraud monitoring, whether funds are held in escrow or routed directly
   - **Healthcare**: PHI storage and encryption, audit logging of record access, consent capture
   - **Minors involved**: parental consent, age gate, no behavioral advertising
   - **Social/UGC**: content moderation, abuse reporting, blocking
4. Prioritize thin sections. Don't move on while a section is under its minimum, unless the user explicitly marks it N/A.
5. If the user says "not sure" / "you decide," log a sensible default, mark it as an assumption, and move on — never block. This is especially common for Tech Stack and App Store Readiness; that's fine, but every assumption must appear in `meta.assumptionsMade` so the approval gate can surface it.
6. When capturing permissions, capture the **reason** for each (e.g. "camera — uploading food-tasting photos"), since app stores require justifying each permission individually.
7. Watch for silent business-model blockers and raise them proactively. The clearest example: if the app sells anything digital and the user assumed an external payment processor, tell them Apple/Google policy likely requires in-app purchase instead — don't let that surface after the architecture is built.

## Ending the interview

Do not end until every section has met its minimum or been explicitly marked N/A, and no contradictions are unresolved. Then run a completeness check out loud, listing each section with its status, before writing the file.

## Output

Write **`requirements.json`** to the project root. Use exactly these key names — downstream agents read them by name, so do not rename or restructure:

```json
{
  "meta": {
    "domainFlags": ["fintech", "marketplace"],
    "assumptionsMade": ["items left to your judgment"],
    "notApplicable": ["items marked N/A"]
  },
  "discovery": {
    "concept": "...",
    "audience": "...",
    "problem": "...",
    "platform": "mobile only | mobile + web admin dashboard"
  },
  "product": {
    "businessModel": "...",
    "successDefinition": "...",
    "competitors": "...",
    "outOfScope": "...",
    "legalDocs": { "privacyPolicy": "exists | needs drafting", "termsOfService": "exists | needs drafting" },
    "monetizationType": "digital goods (store IAP required) | physical goods or real-world services (external processor allowed) | none",
    "paymentProcessor": "..."
  },
  "uxui": {
    "criticalFlows": "...",
    "brand": "existing guidelines described here | none provided",
    "accessibility": "...",
    "offline": "...",
    "darkMode": "required | not required | agent's choice",
    "tabletSupport": "required | phone only",
    "permissions": [ { "permission": "camera", "reason": "..." } ]
  },
  "localization": {
    "launchLanguages": "...",
    "futureLanguages": "...",
    "localeFormatting": "required | not required",
    "rtlSupport": "required | not required",
    "translationOwner": "..."
  },
  "backend": {
    "entities": "...",
    "integrations": "...",
    "realtime": "...",
    "scale": "...",
    "existingSystems": "...",
    "pushNotifications": { "needed": true, "triggers": "..." },
    "deepLinking": "required | not required",
    "mediaUploads": { "needed": true, "types": "...", "maxSize": "...", "storage": "..." },
    "timezoneHandling": "..."
  },
  "techStack": {
    "mobileFramework": "...",
    "backendFramework": "...",
    "database": "...",
    "hosting": "...",
    "crashReporting": "..."
  },
  "security": {
    "dataCollected": "...",
    "authMethod": "...",
    "biometricLogin": "offered | not offered",
    "accountRecovery": "...",
    "accountDeletion": { "inAppDeletionSupported": true, "notes": "Apple requires in-app deletion where account creation is offered" },
    "sessionManagement": "...",
    "socialLogin": { "offered": true, "providers": "...", "signInWithAppleIncluded": true },
    "dataResidency": "...",
    "retentionPolicy": "..."
  },
  "appStore": {
    "displayName": "...",
    "bundleId": "...",
    "assetsExist": "icon and splash exist | need creating",
    "ageRating": "...",
    "forceUpgrade": "required | not required"
  },
  "qa": {
    "mustNotBreak": "...",
    "deviceCoverage": "...",
    "minOsVersions": "..."
  },
  "support": {
    "inAppSupport": "required | not required",
    "channel": "..."
  },
  "devops": { "releaseCadence": "..." },
  "analytics": {
    "events": "...",
    "personalization": "...",
    "reporting": "..."
  },
  "constraints": {
    "budget": "...",
    "timeline": "...",
    "teamSize": "...",
    "inHouseOrOutsourced": "..."
  }
}
```

After writing the file, tell the user it's ready and that the next step is the **Architecture / Product Overview agent** (`architecture-agent`).
