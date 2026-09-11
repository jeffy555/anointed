"""Quick auth/DB diagnostic — run: python scripts/diagnose_auth.py"""
from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Ensure backend root is on path when run from scripts/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import jwt
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from app.core.config import settings
from app.main import app


def main() -> None:
    print("=== Settings ===")
    print(f"ENVIRONMENT: {settings.environment}")
    print(f"DATABASE_URL: {settings.database_url}")
    print(f"GOOGLE_OAUTH_CLIENT_IDS: {settings.google_client_id_list}")

    print("\n=== Database ===")
    try:
        engine = create_engine(settings.database_url)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("DB connection: OK")
    except Exception as exc:
        print(f"DB connection: FAIL — {exc}")

    print("\n=== Health ===")
    client = TestClient(app)
    health = client.get("/health")
    print(f"GET /health -> {health.status_code} {health.json()}")

    print("\n=== OAuth (bad JWT) ===")
    bad = jwt.encode(
        {
            "sub": "diag-user",
            "aud": settings.google_client_id_list[0]
            if settings.google_client_id_list
            else "test",
            "iss": "https://accounts.google.com",
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            "iat": datetime.now(timezone.utc),
        },
        "wrong-secret",
        algorithm="HS256",
    )
    r = client.post(
        "/v1/auth/oauth",
        json={"provider": "google", "id_token": bad},
        headers={"X-Install-Id": "diag-install"},
    )
    print(f"POST /v1/auth/oauth (bad JWT) -> {r.status_code} {r.text[:200]}")

    print("\n=== OAuth (dev token — only works when GOOGLE_OAUTH_CLIENT_IDS empty) ===")
    r2 = client.post(
        "/v1/auth/oauth",
        json={
            "provider": "google",
            "id_token": "devtoken:diag-dev:diag@dev.local:Diag",
        },
        headers={"X-Install-Id": "diag-install-2"},
    )
    print(f"POST /v1/auth/oauth (devtoken) -> {r2.status_code} {r2.text[:200]}")


if __name__ == "__main__":
    main()
