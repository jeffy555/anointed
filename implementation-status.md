# Anointed — Implementation Status

**Last updated:** 10 Sep 2026  
**Gate:** `approval.json` approved  
**Audits:** `compliance-report.md`, `flow-validation.md` complete · QA/production-readiness pass 10 Sep 2026

Legend: **implemented** = real working code · **counsel/human** = requires legal counsel or live account audit · **deferred** = documented limitation

---

## QA pass — 10 Sep 2026

A full build audit found 5 critical and 7 major defects. **All five criticals and all seven majors
are now closed.** One correction is recorded below: C4 was over-called — the 16 KB page-size
requirement it named was already met, and measuring the build proved it.

| ID | Finding | Status | Notes |
|----|---------|--------|-------|
| C1 | A release build with no `--dart-define` pointed at a developer loopback | **implemented** | `AppConfig.releaseConfigErrors` refuses a release build that was never given an `API_BASE_URL`, or given one over plain HTTP; `main()` throws on it before the first frame and ahead of `CrashReporting.runGuarded`, so it fails loudly rather than being swallowed by the handler meant to report it. Empty in debug and profile. **Landed outside this session's QA pass**; an unterminated string literal in `assertReleaseConfig()` was breaking the build (100 analyzer errors, 4 test failures) and was repaired |
| C2 | Android release signed with the debug keystore | **implemented** | `signingConfigs.release` now exists and reads `android/key.properties` (gitignored, with a committed `.example`), validating that all four keys are present. `minifyEnabled`, `shrinkResources` and a `proguard-rules.pro` are wired; R8 and resource shrinking verified by an actual release build. Signing verified end-to-end with a throwaway keystore — `apksigner` confirmed the APK carried that certificate rather than the debug one, and the test credentials were then removed |
| C3 | Google's sample AdMob app IDs on both platforms | **implemented** (Android) / **checklist** (iOS) | The Android id is a manifest placeholder fed by `-PadmobAppId`, and `verifyReleaseConfig` fails `assembleRelease`/`bundleRelease` while it is still the sample. iOS has no build-time equivalent, so its id, the `SKAdNetworkItems` list and the signing identity are covered by `docs/ios_release_checklist.md`. `ITSAppUsesNonExemptEncryption=false` and Google's own SKAdNetwork id were added; **the full mediation-partner list still has to be pasted from Google before submission** |
| C4 | Toolchain below the Play floor | **implemented** / **partly withdrawn** | The `targetSdk` half was real and is fixed (pinned to 36 rather than inheriting Flutter's 34). **The 16 KB half was wrong**: the claim that Flutter 3.24.5 cannot emit 16 KB-aligned libraries was reasoning from the SDK's age, not from the build. Measured on the release APK, every native library passes — `libflutter.so` at 64 KB alignment, the rest at 16 KB — confirmed by parsing ELF program headers and again with the NDK's `llvm-readelf`, and `zipalign -c -P 16` reports every `.so` stored uncompressed and page-aligned ("Verification successful"). **No SDK upgrade is required to ship.** Upgrading remains worthwhile as maintenance, and `targetSdk 36` brings Android 15 edge-to-edge enforcement that needs a device check |
| C5 | Kids Zone music and narration played on after backgrounding | **implemented** | `didChangeAppLifecycleState` had no `paused` branch at all. Ambience pauses and TTS stops on `paused`/`hidden`/`detached`; `inactive` is deliberately ignored so the notification shade does not stutter the music. Two separate pause flags in `KidsZoneAudioService`, because backgrounding mid-narration sets both |
| J1 | 21 of 72 Kids Zone frames overflowed | **implemented** | 4 at 360×720 default text, 6 in landscape, 11 at text scale 1.6. Three shared widgets in `kids_zone_game_shell.dart` + per-site fixes; Kids Zone locked to portrait. Now 0 of 108, up to the app's own 2.4 ceiling. See `kids.md` |
| J2 | Fonts fetched from Google at runtime | **implemented** | `google_fonts` removed from the dependency tree entirely rather than disabled by flag — only 3 call sites used it. 11 static instances bundled (1.5 MB). Closes both the offline-first-launch fallback and an unsolicited third-party request made before the consent gate |
| J3 | Stale IAP restore timer could resolve a later purchase | **implemented** | The 8s fallback checked the `_pending` field, not its own completer, so a restore that resolved early could finish whoever came next. Now bound via `identical`, re-checked after the `serverStatus()` round trip, and cancelled in `_completePending` and `dispose` |
| J4 | Leaderboard polled every 3 min for the life of the app | **implemented** | `IndexedStack` keeps all four tabs alive and the shell sits under every pushed route, so it polled through gameplay, ad breaks and Kids Zone. Now gated on tab visibility *and* app lifecycle |
| J5 | Kids Zone progress survived sign-out and deletion | **implemented** | `clearAccountScopedState()` now clears stops, stars and the `kids_zone_tutorial_*` keys. Shared family devices no longer hand one child another's progress |
| J6 | Stars computed, shown once, discarded | **implemented** | All 12 engines judged 1–3 stars and nothing kept them, so the hub could only say "done" and there was no reason to replay. Best-of-run persisted per stop and rendered on the hub rows |
| J7 | Double-tapping "finish" completed a stop twice | **implemented** | Two `kids_zone_stop_completed` events and two `pushReplacementNamed` calls per completion. One re-entrancy guard in `KidsZoneGameScreen` covers all 18 games |

### Minor findings

| ID | Finding | Status | Notes |
|----|---------|--------|-------|
| N1 | `EdgeInsets.horizontal` misread doubled the page gutter | **implemented** | `EdgeInsets.horizontal` is left *plus* right, and nine call sites fed that sum back in as a single-side value — so the level map and Kids Zone hub ran at 32 px on a phone instead of 16, while the practice hub (which divided by two) ran at 16. That mismatch is why the tabs did not line up. Fixed at the root: `Layout.pageInset(context)` returns the single number, and every site now uses it |
| N2 | 16 MB of uncompressed WAV background music | **blocked — needs an encoder** | Confirmed the source: 3 x 60 s mono 44.1 kHz 16-bit, 5.05 MB each. No encoder is installed on this machine and fetching one ran at ~1 MB/min against an 80 MB download, which is not proportionate to a minor finding. `scripts/encode_kids_zone_audio.py` is ready to run against any ffmpeg and encodes to **AAC in M4A**, not the obvious choices: Ogg Vorbis would fail silently on iOS (`audioplayers` there is AVAudioPlayer, which cannot decode it), and MP3 gaps audibly at every loop point because its encoder delay is not described in the container. Expect roughly 16 MB down to ~2 MB |
| N4 | Tablet navigation rail drew the same icon four times | **implemented** | Every `NavigationRailDestination` used `Icons.circle_outlined`/`Icons.circle`, so on the layout where the icon is largest and the label smallest, only the text told the tabs apart. Each now has its own outline/filled pair: map, trophy, school, person |
| N5 | Adventure and stop copy sat outside the ARB | **implemented** | 48 strings — 6 adventure names and subtitles, 18 stop names and teasers — moved into `app_en.arb`. The catalogue now holds ids, order, colour and which game a stop runs; everything a player reads resolves through `kids_zone_strings.dart`. Switches on the id rather than a map, so `l10n.kidsZoneStopArk1Title` is a real getter and a typo is a compile error. `kids_zone_strings_test.dart` asserts every catalogue id resolves, since a missing string degrades to a blank row rather than an error |
| N6 | Eight `use_build_context_synchronously` sites | **implemented** | All eight fixed, not just the one with a live crash path. Each was a `context` lookup after an await — an OS permission dialog, an OAuth round trip, a pushed route, a confirm dialog — so each now resolves what it needs *before* the await. `flutter analyze` goes from 12 issues to 3, which matters beyond tidiness: 8 known-benign warnings is how a real one gets missed |
| N7 | Manifest and store-metadata gaps | **implemented** | The launcher showed the lowercase `anointed`; it is now `@string/app_name` = "Anointed" — a resource rather than a literal, so a `values-xx/strings.xml` can localise it later. Verified in the built APK: `application-label:'Anointed'`. `android:allowBackup="false"` added, which is a compliance decision more than a technical one: Auto Backup would have copied the cached child profile into the account holder's Drive, and the encrypted preferences behind `flutter_secure_storage` whose keys do not survive a restore onto another device. `ITSAppUsesNonExemptEncryption` was already added with C3 |
| N8 | Five smaller items | **implemented** | **a** unused `state_views.dart` import removed — the last analyzer *warning*. **b** `onPopInvoked` → `onPopInvokedWithResult`. **c** the three `popUntil` predicates now fall back to `route.isFirst`; a predicate that never matches pops every route and leaves a black screen, and they matched only because there is exactly one push path into the zone. **d** the orphaned `heroes_1` catalogue entry removed — unreachable config reads as a feature. **e** the stale "25 tests" in the docs, already corrected |
| N3 | No `RepaintBoundary` anywhere in the app | **implemented** | The seven full-screen animated scenes repaint every frame by design, but shared a layer with the HUD over them, so the score, hearts and buttons were re-rasterised at the same rate. Each scene now has its own layer |

**Verification:** `flutter analyze` — **no issues found**, down from 12. `flutter test` — **275 pass** (was
156). New suites: `kids_zone_layout_test.dart` (108 cases), `kids_zone_progress_test.dart`,
`kids_zone_strings_test.dart`.

Still open: **N2** alone (audio re-encode, blocked on tooling — see `scripts/encode_kids_zone_audio.py`).
`flutter analyze` now reports **no issues at all**, down from 12.

---

## Polish pass — Sep 2026

| Area | Status | Notes |
|------|--------|-------|
| Parchment Codex visual consistency | **implemented** | Leaderboard, Practice, Profile, Support, splash, level complete aligned with map tab |
| Stained Glass dead code | **implemented** | Removed `stained_glass_*.dart` |
| Splash / brand wordmark | **implemented** | `AnointedWordmark` widget (Parchment Codex typography) |
| Level complete celebration | **implemented** | Animated trophy + confetti burst (`CelebrationAnimation`) |
| `image_clue` character images | **implemented** | `GET /v1/content/assets/{key}` SVG portraits; `CharacterImage` + offline fallback |
| Kids read-aloud / TTS | **implemented** | `flutter_tts`; shown for kid + youth age groups in ranked + practice gameplay |
| FAQ / support copy | **implemented** | Server FAQ expanded (phone recovery); ARB + support screen copy updated |
| Phone recovery UX | **implemented** | Sign-in recovery card, clearer 404 copy, support preset to account category |

---

## Kids Zone — Sep 2026

| Area | Status | Notes |
|------|--------|-------|
| Mode chooser (all signed-in users) | **implemented** | `PlayModeChooser` on M-11 level map — Main Journey vs Kids Zone |
| Adventure hub (M-32) | **implemented** | Sky-themed world; 5 adventures / 12 stops (not 100-level map) |
| Adventure 1 — Creation Garden (Genesis 1) | **implemented** | Intro + 3 levels: listen/Q&A, connect days, jumble + rainbow |
| Adventure 2 — Battle of Siddim (Genesis 14) | **implemented** | Narrated intro + 3 archery levels covering rounds 1-6; round 6 is the King's Round |
| Archery engine | **implemented** | `ArcheryGame` — `Ticker` loop, drag-to-aim/release-to-shoot, zig-zag soldiers, courage meter, per-round scoring |
| Adventure 3 — Noah's Ark (Genesis 6-9) | **implemented** | Narrated intro + 3 levels: ark builder puzzle, two-by-two memory match, animal care sim |
| Ark builder engine | **implemented** | `ArkBuilderGame` — `Draggable`/`DragTarget` snap-to-blueprint, 3 cumulative build stages (14 pieces) |
| Animal care engine | **implemented** | `AnimalCareGame` — `Ticker` needs loop, patience rings, tool selection, happiness meter |
| Stop completion (M-34) | **implemented** | Stars + celebration; local progress in `LocalStore` |
| Analytics | **implemented** | `kids_zone_entered`, `kids_zone_stop_started`, `kids_zone_stop_completed` (both adventures) |
| Catalog tests | **implemented** | `test/kids_zone_adventures_test.dart` — stop/game wiring, round escalation |
| Stars persisted per stop | **implemented** | Best-of-run kept in `LocalStore`, shown on the hub (QA J6) |
| Portrait lock | **implemented** | Set on the hub, released on exit; main journey keeps its landscape/tablet layouts (QA J1) |
| Layout regression suite | **implemented** | `kids_zone_layout_test.dart` — 18 stops × 6 frames, to the 2.4 text ceiling |
| Server sync | **deferred** | Progress is device-local; cloud sync can follow if needed |

---

## Compliance gaps — resolution status

| ID | Finding | Status | Notes |
|----|---------|--------|-------|
| LB-1 | Privacy Policy not drafted | **counsel/human** | Draft HTML at `/legal/privacy`; `docs/legal/README.md` |
| LB-2 | Terms of Service not drafted | **counsel/human** | Draft HTML at `/legal/terms`; update URLs when live |
| LB-3 | No scheduler for consent cleanup | **implemented** | `maintenance.py` + hourly loop in `main.py` lifespan |
| P-4 | Apple sandbox default in production | **implemented** | Default `False`; production boot guard |
| CORS-1 | Wildcard CORS + credentials | **implemented** | Production guard |
| C-10 | VPC consent copy placeholder | **counsel/human** | COPPA-oriented draft; counsel sign-off required |
| C-11 | AdMob live account audit | **counsel/human** | `ADMOB_PRODUCTION_ACK` gate + checklist |
| P-3 | IAP receipt edge cases | **implemented** (partial) | ASN V2 async revocation **deferred** |

---

## Build order — backend

| Slice | Status | Notes |
|-------|--------|-------|
| 0.1–B.13 | **implemented** | See prior status; adaptive difficulty wired (Sep 2026) |
| Character asset endpoint | **implemented** | `/v1/content/assets/{key}` + seed `image_clue` mix |

## Build order — mobile (Flutter)

| Slice | Status |
|-------|--------|
| M-01–M-31 screens | **implemented** |
| M-32–M-34 Kids Zone | **implemented** |
| Kids Zone adventure 2 (Battle of Siddim) | **implemented** |
| Kids Zone adventure 3 (Noah's Ark) | **implemented** |
| Parchment Codex tab chrome | **implemented** |
| TTS read-aloud (kids) | **implemented** |
| Character image rendering | **implemented** |

---

## Remaining before store submission

0. **Provision the real credentials** — the build now *refuses* to produce a release without them,
   so this is provisioning rather than coding: create the upload keystore and fill
   `android/key.properties` (see `.example`), and pass the real AdMob id via `-PadmobAppId`. For iOS,
   work `docs/ios_release_checklist.md`.
1. **Android 15 edge-to-edge device check** — targeting SDK 36 means the system draws the app behind
   the status and gesture bars whether it asks to or not, on an engine from Nov 2024. Not a blocker,
   but worth an hour on a real Android 15 handset, especially in Kids Zone where the games manage
   system UI themselves.
2. **Flutter SDK upgrade** — maintenance, not a blocker (see the C4 correction above). Worth a
   scheduled window while nothing depends on it.
1. **Legal counsel** — finalize Privacy Policy + ToS; set production URLs
2. **AdMob** — complete COPPA checklist; set `ADMOB_PRODUCTION_ACK=true`
3. **Launch content (OQ-11)** — ~2,000 curated questions via Admin
4. **Final brand assets** — replace programmatic wordmark with counsel-approved artwork when ready
5. **App Store Server Notifications V2** — optional IAP revocation follow-up

---

## Verification

| Check | Result | Notes |
|-------|--------|-------|
| `pytest` (backend) | **not run** | `pytest` is not installed in `backend/.venv`; includes `test_character_assets.py`, `test_adaptive_difficulty.py` |
| `flutter pub get` + `gen-l10n` | required | `google_fonts` **removed**; fonts now bundled in `mobile/assets/fonts` |
| `flutter analyze` | pass (10 Sep 2026) | **no issues found** (was 12) |
| `flutter test` | pass (10 Sep 2026) | **275 tests** |
| Kids Zone layout matrix | pass (10 Sep 2026) | 108 cases — 18 stops × 6 device frames |
| Release-config guard | pass (10 Sep 2026) | `AppConfig.assertReleaseConfig()` in `main()`; Gradle `verifyReleaseConfig` on `assembleRelease`/`bundleRelease` |
| `flutter build apk --release` | pass (10 Sep 2026) | 75.2 MB universal APK; R8 + resource shrinking clean; mapping.txt emitted; signature verified with `apksigner` |
| `bundleRelease` (Play upload path) | pass (10 Sep 2026) | 45.4 MB app bundle; `verifyReleaseConfig` gates it |
| 16 KB page-size support | pass (10 Sep 2026) | ELF headers + `llvm-readelf` + `zipalign -c -P 16`, all on the built APK |
| On-device run | **not done** | No build was installed this pass, so frame timings, real audio behaviour and store billing are unverified |
