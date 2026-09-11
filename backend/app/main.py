"""Anointed API — FastAPI application entry point.

Routers are mounted under ``/v1``; the embedded admin dashboard lives at ``/admin``;
the parent-facing VPC confirmation page (M-06F) is served from ``/consent``.
"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager, suppress
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.admin import setup_admin
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.routers import (
    account,
    ads,
    analytics,
    auth,
    consent,
    consent_web,
    content,
    game,
    iap,
    leaderboard,
    legal,
    version,
)
from app.services.maintenance import run_consent_maintenance

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)-8s %(name)s %(message)s",
)
logger = logging.getLogger("anointed")

STATIC_DIR = Path(__file__).resolve().parent / "web" / "static"


async def _maintenance_loop() -> None:
    """Run COPPA cleanup hourly (compliance-report LB-3)."""
    while True:
        await asyncio.sleep(settings.maintenance_interval_seconds)
        try:
            await asyncio.to_thread(run_consent_maintenance)
        except Exception:
            logger.exception("Scheduled consent maintenance failed")


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.is_production:
        _assert_production_secrets()

    logger.info(
        "Starting API (environment=%s, database=%s)",
        settings.environment,
        _safe_db_label(settings.database_url),
    )

    from app.admin.auth import ensure_bootstrap_admin

    created = ensure_bootstrap_admin()
    if created:
        logger.info("Created bootstrap admin user %s", created)

    # Run once at startup, then on the hourly loop.
    try:
        await asyncio.to_thread(run_consent_maintenance)
    except Exception:
        logger.exception("Initial consent maintenance failed")

    task = asyncio.create_task(_maintenance_loop())
    try:
        yield
    finally:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


def _safe_db_label(url: str) -> str:
    """Log-friendly database label without credentials."""
    if url.startswith("sqlite"):
        return url
    if "@" in url:
        return url.split("@", 1)[1]
    return url


def _assert_production_secrets() -> None:
    """Refuse to boot production with development placeholders still in place."""
    problems = []
    if settings.jwt_secret.startswith("dev-only"):
        problems.append("JWT_SECRET is still the development placeholder")
    if settings.admin_session_secret.startswith("dev-only"):
        problems.append("ADMIN_SESSION_SECRET is still the development placeholder")
    if "localhost" in settings.database_url:
        problems.append("DATABASE_URL still points at localhost")
    if settings.apple_iap_use_sandbox:
        problems.append(
            "APPLE_IAP_USE_SANDBOX is true — production receipts will fail validation"
        )
    if settings.cors_allows_wildcard:
        problems.append(
            "CORS_ORIGINS contains '*' with allow_credentials=True — restrict to known admin/web origins"
        )
    if problems:
        raise RuntimeError(
            "Refusing to start in production: " + "; ".join(problems) + ". "
            "See .env.example for the variables that must be set."
        )


app = FastAPI(
    title="Anointed API",
    version="1.0.0",
    description=(
        "Backend for Anointed — a Bible character quiz for kids. "
        "Gameplay is server-authoritative; clients never submit scores."
    ),
    lifespan=lifespan,
)

# Mobile clients do not send Origin headers; credentialed CORS matters for /admin and
# /consent web surfaces. Wildcard + credentials is blocked in production (CORS-1).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=not settings.cors_allows_wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

app.include_router(version.router)
app.include_router(auth.router)
app.include_router(consent.router)
app.include_router(consent_web.router)
app.include_router(legal.router)
app.include_router(game.router)
app.include_router(leaderboard.router)
app.include_router(content.router)
app.include_router(iap.router)
app.include_router(ads.router)
app.include_router(analytics.router)
app.include_router(account.router)

setup_admin(app)


@app.get("/health", tags=["ops"])
def health() -> dict:
    return {"status": "ok", "environment": settings.environment}
