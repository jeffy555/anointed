# Anointed

Bible character guessing quiz for kids (Flutter iOS/Android) with a FastAPI + NeonDB backend and embedded admin dashboard.

## Repository layout

| Path | Description |
|------|-------------|
| `backend/` | FastAPI API, SQLAdmin dashboard, Alembic migrations |
| `mobile/` | Flutter app (in progress) |
| `requirements.json` | Product requirements |
| `design-spec.md` | UX / screen inventory |
| `feature-plan.md` | Build order |
| `approval.json` | Pipeline approval gate |
| `implementation-status.md` | What is implemented vs pending |

## Getting started

**Backend** — see [backend/README.md](backend/README.md).

**Mobile** — Flutter scaffold pending Code Generator run 2. API base URL for local dev: `http://localhost:8000`.

Flutter SDK (3.24.5 stable) is installed at `.flutter/` in this repo. Add to your shell before building:

```bash
export PATH="/mnt/d/Anointed/.flutter/bin:$PATH"
flutter --version
```

## Pipeline status

- Specs + approval: done
- Backend: done
- Flutter: done
- Security / flow validation: next
- Implementation Agent: after audits
