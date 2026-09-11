# Anointed — Flutter mobile app

Bible character quiz game (M-01–M-31). Connects to the FastAPI backend in `../backend/`.

## Prerequisites

- Flutter SDK ≥ 3.24 (`flutter doctor`)
- A running backend (default `http://localhost:8000`, or Android emulator `http://10.0.2.2:8000`)

## Run

```bash
cd mobile
flutter pub get
flutter run
```

Point at a custom API:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

## Development auth

When Google/Apple OAuth is not configured in the native project, debug builds use the backend `devtoken:` scheme (`DEV_OAUTH_FALLBACK`, on by default in debug). Release builds require real OAuth client IDs.

```bash
flutter run --dart-define=DEV_OAUTH_FALLBACK=true
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-client-id.apps.googleusercontent.com
```

## Routing

Navigator 1.0 with named routes (`lib/core/routes.dart`). No deep links in v1 — `go_router` is intentionally omitted.

## Localization

ARB source: `lib/l10n/app_en.arb`. Generated code: `lib/l10n/gen/` (via `flutter gen-l10n` / `l10n.yaml`).

## Practice content

Ranked play fetches questions live from `/v1/game/*`. Practice mode reads the on-device pack (`ContentService`): bundled seed JSON plus background sync from `/v1/content/*`.

## Firebase / AdMob / IAP

- **Firebase Crashlytics** — optional; no-ops without `google-services.json` / `GoogleService-Info.plist`
- **AdMob** — interstitials for 13+ only; skipped when ad units are unset
- **IAP** — single non-consumable unlock SKU; store + server validation via `/v1/iap/*`

## Platform notes

- Sign in with Apple is shown on **iOS only**
- Account deletion disclosure strings come from the server (`/v1/account/deletion-preview`) so legal copy can change without a store release
- Local notifications only (no FCM); opt-in after first level complete or in Settings

## Tests

```bash
flutter analyze
flutter test
```

## Project layout

| Path | Role |
|------|------|
| `lib/core/` | API client, routes, theme, config |
| `lib/services/` | Repositories and platform integrations |
| `lib/state/` | Session, bootstrap, settings |
| `lib/features/` | Screens (M-01–M-31) |
| `lib/widgets/` | Shared UI |
| `assets/content/` | Seed practice pack |
