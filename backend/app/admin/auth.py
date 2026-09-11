"""Admin authentication (A-01) — email + password against ``AdminUser``."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqladmin.authentication import AuthenticationBackend
from sqlalchemy import select
from starlette.requests import Request
from starlette.responses import RedirectResponse

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import hash_password, verify_password
from app.models.analytics import AdminUser
from app.services import analytics

SESSION_KEY = "admin_user_id"
MAX_FAILED_LOGINS = 10


class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        email = str(form.get("username", "")).strip().lower()
        password = str(form.get("password", ""))

        with SessionLocal() as db:
            admin = db.execute(
                select(AdminUser).where(AdminUser.email == email)
            ).scalar_one_or_none()

            failure_reason: str | None = None
            if admin is None or not admin.is_active:
                failure_reason = "invalid_credentials"
            elif admin.failed_login_count >= MAX_FAILED_LOGINS:
                failure_reason = "account_locked"
            elif not verify_password(password, admin.password_hash):
                failure_reason = "invalid_credentials"
                admin.failed_login_count += 1

            analytics.track(
                db,
                "admin_login",
                admin_user_id=admin.id if admin else None,
                platform="web_admin",
                properties={
                    "outcome": "failure" if failure_reason else "success",
                    "failure_reason": failure_reason,
                },
            )

            if failure_reason or admin is None:
                db.commit()
                return False

            admin.failed_login_count = 0
            admin.last_login_at = datetime.now(timezone.utc)
            admin_id = str(admin.id)
            db.commit()

        request.session.update({SESSION_KEY: admin_id})
        return True

    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool | RedirectResponse:
        admin_id = request.session.get(SESSION_KEY)
        if not admin_id:
            return RedirectResponse(request.url_for("admin:login"), status_code=302)

        with SessionLocal() as db:
            try:
                admin = db.get(AdminUser, uuid.UUID(admin_id))
            except (ValueError, TypeError):
                admin = None
            if admin is None or not admin.is_active:
                request.session.clear()
                return RedirectResponse(request.url_for("admin:login"), status_code=302)
        return True


def current_admin_id(request: Request) -> uuid.UUID | None:
    raw = request.session.get(SESSION_KEY)
    try:
        return uuid.UUID(raw) if raw else None
    except (ValueError, TypeError):
        return None


def current_admin_email(request: Request) -> str | None:
    admin_id = current_admin_id(request)
    if admin_id is None:
        return None
    with SessionLocal() as db:
        admin = db.get(AdminUser, admin_id)
        return admin.email if admin else None


def ensure_bootstrap_admin() -> str | None:
    """Create the first admin from env vars if the table is empty.

    Without this there is no way to reach ``/admin`` on a fresh database. Runs only
    when both variables are set and no admin exists yet.
    """
    if not settings.admin_bootstrap_email or not settings.admin_bootstrap_password:
        return None

    with SessionLocal() as db:
        existing = db.execute(select(AdminUser).limit(1)).scalar_one_or_none()
        if existing is not None:
            return None
        admin = AdminUser(
            email=settings.admin_bootstrap_email.strip().lower(),
            password_hash=hash_password(settings.admin_bootstrap_password),
            role="owner",
        )
        db.add(admin)
        db.commit()
        return admin.email
