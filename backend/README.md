# Anointed API

FastAPI backend for the Anointed Bible character quiz. Gameplay is **server-authoritative** — clients never submit scores. Admin dashboard is embedded at `/admin` via SQLAdmin (AdminJS-equivalent for Python).

## Quick start

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env
# Edit DATABASE_URL to point at NeonDB or local Postgres

alembic upgrade head
python -m app.scripts.seed_content --questions-per-level 15 --publish
uvicorn app.main:app --reload --port 8000
```

- API docs: http://localhost:8000/docs
- Admin: http://localhost:8000/admin
- Health: http://localhost:8000/health
- VPC web page (M-06F): http://localhost:8000/consent/verify/{token}

## Admin dashboard note

The spec calls for AdminJS; this scaffold uses **SQLAdmin** — a Python-native embedded admin with the same functional mapping (A-01–A-13). It mounts at `/admin`, shares the FastAPI process, and supports custom publish/export actions.

## Dev auth without OAuth credentials

When `GOOGLE_OAUTH_CLIENT_IDS` is empty, Google sign-in accepts dev tokens:

```
devtoken:<subject>:<email>:<name>
```

Apple uses the same prefix when `APPLE_BUNDLE_IDS` is cleared in tests; in dev, set bundle IDs and use real tokens or the dev prefix pattern documented in `app/integrations/oauth.py`.

## Seed content (Track A.3)

The seed script is for **dev/QA only**, not launch content:

```bash
python -m app.scripts.seed_content --questions-per-level 20 --publish
```

Launch content (~2,000 questions) should be authored through `/admin`.

## Tests

```bash
ENVIRONMENT=test pytest -q
```

Tests use an isolated SQLite database per case — no Postgres required for CI/local test runs.

## API surface (v1)

| Area | Prefix |
|------|--------|
| Force upgrade | `GET /v1/version/minimum` |
| Auth | `/v1/auth/*` |
| VPC | `/v1/consent/*` + `/consent/verify/{token}` (web) |
| Gameplay | `/v1/game/*` |
| Leaderboard | `/v1/leaderboard` |
| Content sync | `/v1/content/manifest`, `/v1/content/practice-pack` |
| IAP | `/v1/iap/*` |
| Ads | `/v1/ads/*` |
| Analytics | `POST /v1/analytics/events` |
| Account | `/v1/account/*` |

## Handoffs (Implementation Agent)

Marked in code with `HANDOFF(Implementation Agent)`:

- IAP receipt edge cases (real money)
- VPC legal copy / counsel sign-off
- AdMob COPPA configuration audit

## Docker (local dev only)

```bash
docker build -f Dockerfile.dev -t anointed-api .
docker run --env-file .env -p 8000:8000 anointed-api
```

Deployment configuration is intentionally out of scope for this scaffold.
