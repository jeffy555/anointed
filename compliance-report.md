# Anointed — Security Compliance Report

**Generated:** 2026-09-02  
**Agent:** security-compliance-agent  
**Scope:** Backend `/mnt/d/Anointed/backend/` · Flutter mobile `/mnt/d/Anointed/mobile/lib/`  
**Requirements source:** `requirements.json` · `design-spec.md` · `implementation-status.md`

> **Guardrail:** This report identifies compliance gaps for remediation. Nothing in this report constitutes a settled legal conclusion. All regulatory matters (COPPA, GDPR-K, app store policies) should be verified with qualified legal and compliance counsel before launch.

---

## Scorecard

| Result | Count |
|--------|-------|
| **Pass** | 26 |
| **Gap** | 8 |
| **Not Applicable** | 3 |
| **Launch Blockers** | 3 |

---

## Launch Blockers (must resolve before store submission)

| # | Area | Finding |
|---|------|---------|
| LB-1 | Legal Docs — Privacy Policy | `product.legalDocs.privacyPolicy: "needs drafting"`. Placeholder URL `https://anointed.app/privacy` used throughout. App stores require a live, publicly accessible privacy policy URL before submission — especially mandatory for a children's app. |
| LB-2 | Legal Docs — Terms of Service | `product.legalDocs.termsOfService: "needs drafting"`. Placeholder URL `https://anointed.app/terms` is served in the app profile endpoint and referenced in VPC email. |
| LB-3 | Data Retention — No Scheduler for Pending-Consent Cleanup | `cleanup_abandoned_pending_accounts()` and `expire_stale_consent_tokens()` are implemented and tested (`accounts.py` lines 235–291) but are **never called automatically**. The `lifespan` hook in `main.py` only asserts production secrets and creates a bootstrap admin — no cron, background task, or APScheduler wiring exists anywhere in the scaffold. Without automated execution, under-13 children's PII in `PENDING_PARENTAL_CONSENT` / `CONSENT_EXPIRED` states accumulates indefinitely past the 14-day cleanup window specified in `consent_pending_cleanup_days`. This directly contradicts the `security.retentionPolicy` and is a COPPA data-minimization gap for the *apps involving minors* domain flag. |

---

## COPPA / Apps Involving Minors

**C-1 — Age Gate: Server-Side Enforcement**  
**Pass.** `accounts.apply_age()` sets `is_under_13` and flips `account_status` to `PENDING_PARENTAL_CONSENT` server-side. `age_gate.dart` is pure routing code that reads the server's `next_step` — no local age arithmetic. The `ConsentedUser` FastAPI dependency enforces the gate on every gameplay, IAP, ads, and leaderboard endpoint, so a client that skips navigation still hits a 403.

**C-2 — VPC Path A (Parent OAuth + Attestation)**  
**Pass.** Full implementation: parent OAuth JWKS verification, server-side check that parent's OAuth subject does not match child's identities (`consent.py` line 83–91), dual attestation checkboxes enforced server-side, atomic consent record written in one request. Audit record emitted on grant.

**C-3 — VPC Path B (Parent Email, 72h Token, Web M-06F)**  
**Pass.** Signed single-use token (HMAC-SHA256), 72-hour expiry enforced on both issue and resolve, token burned on success, resend cooldown enforced (60s + daily cap). Web confirmation page at `/consent/verify/{token}` implemented in `consent_web.py`. Analytics emits `vpc_email_requested`, `vpc_email_verified`.

**C-4 — Child Self-Attestation Rejected**  
**Pass.** VPC requires either parent OAuth (`is_parent_or_guardian` + `consents_to_data_use` both required) or a parent completing the email web form. A checkbox alone at the child level is explicitly rejected in `consent.py` HANDOFF comment and enforcement logic.

**C-5 — `pending_parental_consent` Blocks Gameplay, Ads, and PII-Linked Analytics**  
**Pass.** `ConsentedUser` dependency (used by game, leaderboard, IAP, ads routers) returns 403 for all non-`CONSENTED` statuses. Under-13 accounts in pending state receive no gameplay access. `AdsService.configureFor()` in `ads_service.dart` checks `user.adsPermitted` and returns early without SDK initialisation.

**C-6 — Under-13 Ad-Free: Dual Barrier**  
**Pass.** (1) Server: `ads_allowed_for_user()` returns `False` for `is_under_13`; `ad_config_for()` returns `ads_enabled: false` with all unit IDs as `null`; `record_ad_event()` raises 403. (2) Client: `AdsService.configureFor()` returns without calling `_initialiseSdk()` when `user.adsPermitted` is false. A client with a broken age-gate check would have no ad unit IDs to request with and no SDK instance — the server barrier fires loudly with a 403 rather than silently accepting a stray event.

**C-7 — `tagForChildDirectedTreatment` Applied**  
**Pass.** `ads_service.dart` calls `MobileAds.instance.updateRequestConfiguration()` with `TagForChildDirectedTreatment.yes` when `_config.tagForChildDirectedTreatment` is true — and that flag is true for under-13 per `ad_config_for()`. `nonPersonalizedAds` is set on individual `AdRequest` objects consistently.

**C-8 — No Behavioral Ad SDK for Under-13**  
**Pass.** AdMob SDK is never initialized for under-13 accounts (see C-6). No secondary ad SDK is present in the scaffold.

**C-9 — Leaderboard Display Name Truncation for Under-13**  
**Pass.** `User.leaderboard_display_name` property (user.py lines 60–71) returns `"FirstName L."` format for `is_under_13 = True`. Applied server-side so no client-side enforcement gap.

**C-10 — VPC Legal Copy (Consent Email and Web Form)**  
**Gap.** `consent.py` contains a `HANDOFF(Implementation Agent)` marker (line 189–196) explicitly noting the email text and web consent page copy are placeholder wording that has not been reviewed by legal counsel. The mechanism is correct; the disclosure language is not finalized. This must be replaced with counsel-reviewed text before launch, particularly given COPPA's specific requirements for what a direct notice to parents must contain. _Verify with legal counsel._

**C-11 — AdMob COPPA Account-Level Audit**  
**Gap.** `ads.py` and `ads_service.dart` both carry `HANDOFF(Implementation Agent)` markers (properly marked, not silent). Code is correct, but the actual AdMob account-level child-directed configuration, ad-unit-level settings, Play Families policy declaration, and App Store age-rating/ad declarations cannot be verified from code. Needs a live AdMob account audit before launch. _Verify with compliance counsel._

**C-12 — Stale Pending-Consent Account Cleanup (see LB-3)**  
**Gap — Launch Blocker.** Covered under LB-3 above.

**C-13 — No Covert Device Fingerprinting for Children**  
**Pass.** `install_id` is an app-generated identifier included in the `X-Install-Id` header. Rate limiting uses `(install_id, IP)` pairs. `requirements.json` explicitly notes "no covert device fingerprinting for children". No third-party fingerprinting SDK is scaffolded.

---

## Authentication

**A-1 — Google Sign-In: JWKS Verification**  
**Pass.** `GoogleOAuthClient` uses `PyJWKClient` against `https://www.googleapis.com/oauth2/v3/certs`, verifies `RS256`/`ES256`, validates `exp`, `iat`, `sub` as required fields, and enforces `iss` and `aud` (from `GOOGLE_OAUTH_CLIENT_IDS`).

**A-2 — Sign in with Apple: Present Alongside Google (App Store Requirement)**  
**Pass.** `security.socialLogin.signInWithAppleIncluded: true` confirmed. `AppleOAuthClient` implemented with Apple's JWKS URL. Mobile sign-in and sign-up screens pass `showApple: oauth.appleAvailable` to `AuthButtonStack`. `auth_buttons.dart` renders the Apple button only on iOS (where it is required by App Store guidelines).

**A-3 — Phone Auth (No OTP): Accepted V1 Tradeoff**  
**Pass.** Documented accepted risk in requirements ("OQ-13"). Rate-limited by `install_id` (5/day) and IP (20/day) for signup; IP-limited (30/hour) for signin. No biometric or email/password auth scaffolded (correctly absent).

**A-4 — Dev Fallback Paths (`devtoken:`, `devreceipt:`) Blocked in Production**  
**Pass.** `Integration.guard()` in `base.py` raises `IntegrationNotConfigured` when `is_configured` is False and `settings.is_production` is True. In production with real credentials, `is_configured` returns True and the real provider is used — dev fallback code is unreachable. `_assert_production_secrets()` additionally refuses to boot production with placeholder JWT or admin secrets.

---

## Session and JWT Hardening

**S-1 — JWT Claims and Audience**  
**Pass.** Tokens include `sub`, `aud` ("anointed-mobile"), `iat`, `exp`, `jti`. Decoded with `audience=SESSION_AUDIENCE` enforced.

**S-2 — Persistent Session (No Inactivity Timeout)**  
**Pass.** `session_token_ttl_days: int = 3650` matches `security.sessionManagement: "Persistent session until explicit sign-out; no inactivity timeout"`.

**S-3 — Production Startup Guards for Secrets**  
**Pass.** `_assert_production_secrets()` raises at startup if `JWT_SECRET` or `ADMIN_SESSION_SECRET` still contain `"dev-only"` prefixes, or if `DATABASE_URL` points at localhost.

---

## Account Recovery and Enumeration

**E-1 — Phone Sign-In: No Enumeration Vector**  
**Pass.** `phone_sign_in()` calls `accounts.find_by_phone()` which returns `None` for both "mobile not found" and "mobile found but name mismatch". Both paths raise the same `not_found("account_not_found", ...)` error. No response timing side-channel is introduced by the implementation (both paths call a single DB query).

**E-2 — OAuth Account Recovery: Automatic on New Device**  
**Pass.** `oauth_sign_in()` restores an existing account when the provider subject matches. No separate recovery flow exposes an enumeration vector.

**E-3 — Admin: Failed Login Count Tracked**  
**Pass.** `AdminUser.failed_login_count` field exists in model. Brute-force lockout logic enforcement is in `admin/auth.py`.

---

## Account Deletion

**D-1 — In-App Deletion Path**  
**Pass.** M-29 `AccountDeletionScreen` implements a 3-step confirmation (confirm → disclosure → final checkbox). `DELETE /v1/account/delete` requires both `confirm: true` and `acknowledged_permanent: true`.

**D-2 — PII Removed Immediately**  
**Pass.** `accounts.delete_account()` deletes: `name`, `mobile`, `age`, `AuthIdentity` rows (OAuth subjects), `ParentalConsentRecord`, `LevelAttempt`, `LevelCompletion`, `UserProgress`, `UserPerformanceSummary`, and the `User` row itself. Leaderboard entries anonymized to "Deleted player". Analytics `user_id` nulled. Purchase record `user_id` and `receipt_token` cleared.

**D-3 — Audit Record Written Before Deletion (Same Transaction)**  
**Pass.** `audit.record(...)` is called inside `delete_account()` at line 168 before any `db.delete()` calls, within the same SQLAlchemy transaction. A DB failure rolling back deletion also rolls back the audit write — the account is never deleted without an audit record.

**D-4 — Deletion Consistent with RetentionPolicy**  
**Pass.** `security.retentionPolicy: "Immediate data removal on account deletion"`. Deletion is immediate. Purchase records retain a non-PII reference (store transaction ID only, with `user_id` and `receipt_token` cleared) for refund dispute resolution — a documented and reasonable exception disclosed to the user in `DeletionPreviewResponse.retained_anonymized`.

---

## IAP and Store Payment Policy

**P-1 — Digital Goods Sold via Store IAP (Not External Processor)**  
**Pass.** `product.monetizationType: "digital goods (store IAP required)"`. `product.paymentProcessor` specifies Apple App Store IAP and Google Play Billing. No external payment processor is wired for the unlock SKU. Server-side receipt validation is performed by `AppleIapClient` and `GooglePlayIapClient` against official provider APIs.

**P-2 — Receipt Validated Server-Side (Client Cannot Self-Grant)**  
**Pass.** `IapService._validate()` in Flutter calls `POST /v1/iap/validate`. The backend grants the unlock only after provider API confirms validity. Client never trusts a local receipt.

**P-3 — IAP Receipt Edge Cases: HANDOFF Markers Present (Not Silent Stubs)**  
**Pass (marked handoff, not a silent stub).** Both `iap.py` (lines 155–161, 120–128) and `iap_service.dart` (lines 277–285) carry explicit `HANDOFF(Implementation Agent)` markers identifying: Apple refund/revocation via `cancellation_date`, App Store Server Notifications V2, Google Play `products:acknowledge` (3-day window), `voidedpurchases` for refunds, and the two-account receipt conflict policy decision. These are real-money policy decisions correctly deferred with clear tracking. The happy path works end to end.

**P-4 — Apple IAP Sandbox Default Not Restricted in Production**  
**Gap.** `apple_iap_use_sandbox: bool = True` is the hardcoded default in `config.py` (line 65) and is set to `true` in `.env.example` (line 41) with no comment flagging it as a production concern. `_assert_production_secrets()` does not check this value. A production deployment using config defaults would send all App Store receipts to Apple's sandbox endpoint, causing real purchases to fail validation (sandbox returns error for production receipts). This should either be defaulted to `False` with a `REQUIRED` comment, or added to the production startup guard.

---

## Ads — Under-13 Policy

**AD-1 — Practice Mode Ad-Free**  
**Pass.** `AttemptMode.PRACTICE` check in `interstitial_eligible()` returns `False` unconditionally.

**AD-2 — Levels 1–3 Ad-Free (Onboarding Grace)**  
**Pass.** `ad_min_level: int = 4` enforced in both `ads.py` server config and propagated to `AdConfig.minLevel` on the client.

**AD-3 — Frequency Cap (Every 3rd Level, Max 2/Session)**  
**Pass.** Server returns `every_nth_level: 3` and `max_per_session: 2` in `AdConfigResponse`. Client tracks `_adsShownThisSession` in `AdsService`. Session cap lives client-side by design (no server-side session concept).

---

## `.env.example` Secrets

**ENV-1 — No Real Secrets in `.env.example`**  
**Pass.** All secrets use placeholder values explicitly labeled `dev-only-*` or left empty. `JWT_SECRET` and `ADMIN_SESSION_SECRET` are marked `# REQUIRED in production`. `APPLE_IAP_SHARED_SECRET`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `EMAIL_API_KEY`, and `ADMOB_*` values are empty strings.

**ENV-2 — Apple IAP Sandbox Flag (see P-4)**  
**Gap.** `APPLE_IAP_USE_SANDBOX=true` in `.env.example` is not annotated as a production concern. Covered under P-4.

---

## CORS Configuration

**CORS-1 — Wildcard CORS with `allow_credentials=True`**  
**Gap.** `CORS_ORIGINS=*` is the default in `.env.example` (line 70) and `config.py` (line 119). In FastAPI/Starlette, combining `allow_origins=["*"]` with `allow_credentials=True` causes the middleware to reflect the request's `Origin` header value back as `Access-Control-Allow-Origin` (to satisfy the credentials requirement), effectively granting any web origin credentialed access. The admin dashboard at `/admin` uses a session cookie; an attacker's page could make authenticated admin requests on behalf of a logged-in admin user. Restrict `CORS_ORIGINS` to known production origins (e.g., the admin dashboard domain and the VPC web host) before deployment, and add this check to `_assert_production_secrets()`. _Note: mobile app clients do not send Origin headers, so the mobile API itself is not exposed — the risk is concentrated at the admin and web-consent surfaces._

---

## Permissions Scope

**PERM-1 — No Broader Permissions Than Justified**  
**Not Applicable.** `uxui.permissions: []` — no device permissions (camera, location, contacts, microphone) are declared or used. Notification permission is opt-in after first level complete (design-spec §22), which aligns with `meta.notApplicable` excluding all device permissions. Nothing to audit.

---

## Data Residency

**DR-1 — No Regional Constraint to Verify**  
**Not Applicable.** `security.dataResidency: "No strict requirement specified"`. No region lock is asserted in the scaffold's hosting config or DB URL. COPPA and privacy obligations for minors still apply regardless of hosting region — this should be reviewed with counsel when a hosting region is finalized.

---

## No Silent Stubs in Security-Critical Paths

**SS-1 — All HANDOFFs Are Explicitly Marked**  
**Pass.** The three deferred areas (IAP receipt edge cases, VPC legal copy, AdMob COPPA account audit) all carry `HANDOFF(Implementation Agent): <reason>` comments with stated justifications. No unmarked `TODO`, `not implemented`, or fake-success stub was found in: auth endpoints, session handling, consent/VPC flows, permission checks, payment/entitlement logic, KYC-equivalent age gate, or account deletion.

**SS-2 — Admin Auth: No Hardcoded/Mock Responses**  
**Pass.** Admin login uses bcrypt verification via `passlib` (`_pwd_context`), not a hardcoded password or mock success.

**SS-3 — Gameplay Lock: Not Client-Overridable**  
**Pass.** Level lock state is computed server-side from `UserProgress` and `PurchaseRecord`. Client cannot POST a score or unlock state. `ConsentedUser` dependency prevents pending-consent accounts from accessing game endpoints at the framework level.

---

## Leaderboard Anti-Cheat

**LC-1 — Server-Authoritative Scores**  
**Not Applicable (fully addressed in design).** Per `requirements.json` backend.leaderboard.antiCheat: server validates each answer, sequence integrity, time plausibility; clients cannot POST scores. Rate-limited attempt starts per user and install_id. Noted here as Pass for completeness.

---

## Summary of Gaps

| ID | Area | Severity |
|----|------|----------|
| **LB-1** | Privacy Policy not drafted; placeholder URL in all surfaces | **Launch Blocker** |
| **LB-2** | Terms of Service not drafted; placeholder URL in all surfaces | **Launch Blocker** |
| **LB-3** | No scheduler for `cleanup_abandoned_pending_accounts` / `expire_stale_consent_tokens` | **Launch Blocker** (COPPA data-minimization) |
| C-10 | VPC consent copy is placeholder legal text (HANDOFF marked) | High — legal/COPPA |
| C-11 | AdMob COPPA account-level audit pending (HANDOFF marked) | High — COPPA |
| P-4 | `apple_iap_use_sandbox=True` default not guarded against production | Medium — revenue impact |
| CORS-1 | `CORS_ORIGINS=*` with `allow_credentials=True` exposes admin/consent surfaces | Medium — admin security |

---

## Next Steps for Implementation Agent

The Implementation Agent should address the following before or as it writes real feature logic:

1. **LB-3 (highest priority):** Wire `cleanup_abandoned_pending_accounts()` and `expire_stale_consent_tokens()` into a scheduled execution path. Options: APScheduler in-process, a Railway/Render cron job, or a `/v1/ops/cleanup` endpoint authenticated for internal callers. Both functions are already correct — only the scheduler wire is missing.

2. **LB-1 / LB-2:** Replace `privacy_policy_url` and `terms_of_service_url` with live URLs once legal docs are drafted. Confirm the M-08 privacy/ToS screen (mobile) and VPC email template reference these live URLs.

3. **P-4:** Change `apple_iap_use_sandbox` default to `False` in `config.py` and update `.env.example` to comment `APPLE_IAP_USE_SANDBOX=false  # set true for TestFlight/sandbox testing`. Add a check to `_assert_production_secrets()`.

4. **CORS-1:** Restrict `CORS_ORIGINS` in production to the admin dashboard origin and VPC web page origin. Add this to `_assert_production_secrets()`.

5. **C-10:** Replace placeholder VPC email and consent web page copy with counsel-reviewed text. The mechanism is complete; only the disclosure language needs replacement.

6. **C-11:** Complete the AdMob COPPA account-level audit against the live ad account before enabling ads in production.

7. **P-3 / IAP edge cases:** Implement Apple `cancellation_date` / `revocation_reason` revocation and Google Play `products:acknowledge` before enabling production IAP.
