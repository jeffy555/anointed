# Anointed — Feature Plan & Build Order

**Status:** Approved — see `approval.json` (1 Sep 2026). Code Generator may proceed.

**Last updated:** 1 Sep 2026 (incorporates build-order feedback + full spec revisions through §24)

---

## Executive summary

Anointed is a Flutter mobile Bible character quiz (100 levels, kids 6–12 primary) with a FastAPI + NeonDB backend and AdminJS admin dashboard. v1 monetization is IAP-primary (5 free levels, ₹49 unlock). Practice mode is offline; main mode is server-authoritative with anti-cheat leaderboard. Flutter l10n/ARB is included from day one for future Tamil support.

### Risk status (vs. earlier review)

| Earlier concern | Current status |
|-----------------|----------------|
| Undefined parental consent | **Resolved** — VPC Path A (parent OAuth + attestation) + Path B (email confirmation) in design-spec §11 |
| Auth complexity (biometric, SMS OTP) | **Resolved** — v1 is Google / Apple / phone only; biometric and SMS OTP **removed** |
| Content production volume | **Still critical** — 2,000 launch-target questions (20/level); mitigated by AdminJS early + **parallel authoring track** |
| Leaderboard abuse | **Resolved** — server-authoritative LevelAttempt (§21) |
| Practice cache staleness | **Resolved** — content_version + manifest (§19) |
| Low kid ad revenue | **Acknowledged** — under-13 ad-free; 13+ capped ads; ₹49 is intentionally low and ministry/community-scale (§20) |
| Image asset pipeline | **De-risked** — image_clue supported but not launch-blocking; launch baseline is text_qa + verse_clue |

---

## Screen inventory

### Mobile (player)

| Zone | Screens |
|------|---------|
| Launch | M-01 Splash, M-02 Force-upgrade |
| Auth | M-03 Welcome, M-04 Phone sign-up, M-05 Age gate, M-06–M-06F VPC, M-07 Child notice, M-08 Privacy/ToS, M-10 Sign-in |
| Hub | M-11 Level map, M-12 Level detail |
| Gameplay | M-13 Gameplay, M-14 Complete, M-15 Fail, M-16 Timer expired, M-21 Ad break (13+ only) |
| IAP | M-22–M-25 |
| Leaderboard | M-17 |
| Practice | M-18–M-20 |
| Profile | M-26–M-27, M-29–M-30, M-31 Support |

**Removed from v1:** M-09 biometric, M-28 SMS OTP, M-32 biometric login

### Admin (AdminJS — not custom React)

Functional requirements A-01–A-13 mapped to AdminJS resources + custom actions (§23).

---

## End-to-end flows

1. **Launch** — M-01 → version check → M-02 or session routing
2. **Sign-up** — M-03 → (Google/Apple/phone) → age gate → VPC if <13 → M-07 → M-08 → M-11
3. **Sign-in** — M-10 → Google/Apple/phone → M-11
4. **Main gameplay** — M-11 → M-12 → M-13 (server attempt) → M-14/M-15 → M-21 (13+ capped) → next/IAP
5. **IAP** — Complete level 5 or tap locked 6–100 → M-22 @ ₹49 → M-23
6. **Leaderboard** — Validated attempt → server writes entry → M-17 poll
7. **Practice** — M-18–M-20 offline from local pack; content sync on online launch
8. **Account deletion** — M-29 series → hard delete
9. **Force-upgrade** — M-02 blocks all navigation when version below minimum

---

## Integration points

| Integration | v1 status | Notes |
|-------------|-----------|-------|
| Google Sign-In | **Real** | OAuth token verify server-side |
| Sign in with Apple | **Real** (iOS) | Required when Google offered |
| Phone auth | **Real** | mobile + name + age; **no SMS OTP** |
| VPC email (Path B) | **Real interface** | SendGrid/Resend/SES; dev fallback logs link |
| Apple/Google IAP | **Real** | Receipt validation; ~₹49 SKU |
| AdMob | **Real** (13+ only) | Under-13: SDK not initialized |
| Firebase Crashlytics | **Real** | Optional config file guard |
| Firebase Analytics | **Optional** | NeonDB AnalyticsEvent is primary |
| AdminJS | **Real** | Embedded FastAPI `/admin` |
| Local notifications | **Real** | flutter_local_notifications; no FCM server |
| Remote push (FCM/APNs) | **Deferred** | Post-v1 |
| Custom React admin | **Deferred** | AdminJS default |

---

## Build order (revised)

> **Key principles from review:**
> 1. **Force-upgrade first** — beta testers need blocking upgrades before breaking API changes ship.
> 2. **AdminJS early** — content authors use admin UI **in parallel** with mobile; seed/import is not a gate on mobile steps 4–6.
> 3. **No biometric/SMS slice** — removed from v1; do not retrofit.
> 4. **Content = parallel track**, not sequential step 3.

### Phase 0 — Foundation (Days 1–2)

| # | Slice | Delivers | Parallel? |
|---|-------|----------|-----------|
| **0.1** | Repo scaffold | Flutter app + FastAPI monorepo, NeonDB, `.env.example`, Flutter l10n/ARB setup, CI-less deploy to Railway/Render | — |
| **0.2** | **Force-upgrade** | M-01, M-02, `GET /v1/version/minimum` — **first mobile vertical slice** | — |
| **0.3** | **AdminJS core + content publish schema** | `/admin` login, BibleCharacter + Question + Level CRUD, review_status workflow, `ContentPublishRecord`, publish action contract | Enables **Track A** |

### Track A — Content (parallel from Day 2+, non-blocking)

| # | Slice | Delivers |
|---|-------|----------|
| **A.1** | Authoring via AdminJS | Operators create ~300 characters, **20 launch questions/level** (2,000 total), text_qa + verse_clue baseline (§18H) |
| **A.2** | Publish content action | `content_version` bump + practice pack build (§19) |
| **A.3** | Seed/bootstrap script | Optional one-time import for dev/QA — **not a mobile gate**; authors can populate via UI instead |

> Content authors work in Track A while engineering runs Track B. **Milestone before B.5 gameplay starts:** at least 50 levels populated with 15+ approved questions/level (text_qa + verse_clue) so gameplay tests against real content, not only seed fixtures. Final launch target remains 100 levels × 20 approved questions.

### Track B — Mobile + Backend (sequential within track)

| # | Slice | Delivers | Tests |
|---|-------|----------|-------|
| **B.1** | Auth simplified | M-03, M-04, M-10 — Google, Apple, phone; sessions | AUTH-01–15 |
| **B.2** | VPC parental consent | M-06–M-07 series, consent APIs, email web page M-06F | VPC-01–16 🛡 |
| **B.3** | Onboarding completion | M-08, age routing M-05 | AUTH-04–05, AUTH-13 |
| **B.4** | Level map + navigation | M-11, M-12, bottom nav | GAMEPLAY-01 |
| **B.5** | **Server gameplay + anti-cheat** | LevelAttempt start/answer APIs, M-13, text_qa + verse_clue launch baseline, image_clue-ready schema, M-14–M-16 | GAMEPLAY-02–11, LEADERBOARD-01–05 |
| **B.6** | Leaderboard read | M-17, validated entry display, under-13 name masking | LEADERBOARD-06–08 |
| **B.7** | IAP | M-22–M-25, levels 6–100 @ ₹49, free tier 1–5 | IAP-01–07 |
| **B.8** | Ads (13+ capped) | M-21 frequency rules; under-13 skip entirely | ADS-01–06 |
| **B.9** | Practice + content sync | M-18–M-20, manifest/pack download, seed pack in binary | PRACTICE-01–14 |
| **B.10** | Local notifications | M-14 opt-in card, M-27 toggle, 3d/7d schedule | LOCALNOTIF-01–05 |
| **B.11** | Account lifecycle | M-26–M-27, M-29–M-31, deletion | ACCOUNT-01–06 |
| **B.12** | Admin reports + audit | A-10–A-12 via AdminJS custom pages/actions | ADMIN-01–12 |
| **B.13** | Polish | Dark mode, tablet layouts, locale ₹ formatting, accessibility | DARKMODE, TABLET, LOCALE, ACCESS |

### Explicitly removed from build order

| Former step | Status |
|-------------|--------|
| Biometric setup/login (M-09, M-32) | **Removed** — not in v1 |
| SMS OTP recovery (M-28) | **Removed** — not in v1 |
| Custom React admin A-01–A-13 | **Replaced** by AdminJS (Phase 0.3) |
| Sequential "seed all content before mobile" | **Replaced** by parallel Track A |

### Implementation handoffs (Code Generator → Implementation Agent)

| Area | Why handoff |
|------|-------------|
| VPC legal copy + counsel sign-off | Legal/compliance judgment |
| IAP receipt edge cases | Real money |
| AdMob COPPA configuration audit | Compliance verification |
| Adaptive difficulty algorithm | Algorithm unspecified (OQ-08 deferred) |
| Image asset sourcing/storage | Deferred unless assets are ready; image_clue is not launch-blocking |

---

## Priority-ordered `buildOrder` array

For `approval.json` — Code Generator and Implementation Agent read this sequence:

```json
[
  "0.1-scaffold",
  "0.2-force-upgrade",
  "0.3-adminjs-core",
  "B.1-auth-simplified",
  "B.2-vpc-parental-consent",
  "B.3-onboarding-privacy",
  "B.4-level-map",
  "B.5-server-gameplay-anticheat",
  "B.6-leaderboard",
  "B.7-iap",
  "B.8-ads-13plus-capped",
  "B.9-practice-content-sync",
  "B.10-local-notifications",
  "B.11-account-deletion",
  "B.12-admin-reports-audit",
  "B.13-polish-accessibility"
]
```

**Parallel (non-sequential):** Track A (`A.1`–`A.3`) runs alongside `B.4` onward. Engineering provides AdminJS by end of Phase 0; content team starts authoring immediately — do not wait for mobile gameplay to be complete.

---

## Launch blockers (unchanged)

1. **Content volume** — 100 levels × ≥20 approved questions (2,000 total); biggest schedule risk
2. **Privacy Policy + ToS** — must be live before VPC forms link
3. **VPC counsel review** — before US launch
4. **App icon / splash** — store assets
5. **Bundle ID finalization**

---

*Feature Plan — Anointed v1 · Approved*
