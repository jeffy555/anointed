# iOS release checklist

Android refuses to assemble a release build that is misconfigured — see
`verifyReleaseConfig` in `mobile/android/app/build.gradle`, which fails the build
when the keystore or the AdMob app id is missing. **iOS has no equivalent**: the
values below live in `Info.plist` and Xcode will happily build and upload a
bundle carrying every one of the defaults. This list is the guard.

Work through it before any TestFlight or App Store build.

## Blocking

- [ ] **AdMob application id** — `ios/Runner/Info.plist`, `GADApplicationIdentifier`
      is Google's public sample (`ca-app-pub-3940256099942544~1458002511`). It
      serves test ads that earn nothing and attribute to nobody. Replace with the
      real id from the AdMob console.
- [ ] **SKAdNetworkItems** — only Google's own network (`cstr6suwn9.skadnetwork`)
      is listed. Every AdMob mediation partner needs its own entry or its installs
      go unattributed. Paste the current list from
      developers.google.com/admob/ios/quick-start#skadnetwork — it changes as
      partners are added.
- [ ] **API base URL** — the app throws at launch in release mode when
      `API_BASE_URL` is unset or not HTTPS (`AppConfig.assertReleaseConfig`), so a
      misconfigured build fails on first run rather than in the store. Build with:
      `flutter build ipa --dart-define=API_BASE_URL=https://your.api.host`
- [ ] **Signing** — Distribution certificate and provisioning profile, not the
      automatically-managed development pair.

## Worth checking

- [ ] `CFBundleName` is the lowercase `anointed`; `CFBundleDisplayName` is
      correct (`Anointed`) and is what users see. Left as-is deliberately, but
      confirm nothing surfaces the bundle name.
- [ ] Orientation: `Info.plist` permits landscape on iPhone. Kids Zone locks
      itself to portrait at runtime (`kids_zone_hub_screen.dart`); the main
      journey uses its landscape layouts. Confirm both on device.
- [ ] `ITSAppUsesNonExemptEncryption` is declared `false` — correct while the app
      uses only standard HTTPS. Revisit if any custom cryptography is added.
- [ ] Push entitlements are **not** needed: v1 uses local notifications only
      (design-spec §22).

## Not on this list

App-side COPPA and ad-gating configuration lives in
[`admob_coppa_checklist.md`](admob_coppa_checklist.md), and applies to both
platforms.
