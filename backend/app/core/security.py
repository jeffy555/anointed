"""JWT session tokens, password hashing, and signed consent tokens."""

from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

from app.core.config import settings

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SESSION_AUDIENCE = "anointed-mobile"


class TokenError(Exception):
    """Raised when a session or consent token is malformed, expired, or forged."""


# ------------------------------------------------------------------ passwords
def hash_password(raw: str) -> str:
    return _pwd_context.hash(raw)


def verify_password(raw: str, hashed: str) -> bool:
    try:
        return _pwd_context.verify(raw, hashed)
    except ValueError:
        return False


# -------------------------------------------------------------- session token
def create_session_token(user_id: uuid.UUID, *, install_id: str | None = None) -> str:
    """Persistent session per security.sessionManagement — no inactivity timeout."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "aud": SESSION_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.session_token_ttl_days)).timestamp()),
        "jti": secrets.token_urlsafe(12),
    }
    if install_id:
        payload["iid"] = install_id
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_session_token(token: str) -> dict:
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            audience=SESSION_AUDIENCE,
        )
    except jwt.PyJWTError as exc:
        raise TokenError(str(exc)) from exc


# -------------------------------------------------------------- consent token
def generate_consent_token() -> tuple[str, str]:
    """Return ``(raw_token, token_hash)``.

    Only the hash is persisted, so a database read cannot be replayed as a
    consent confirmation.
    """
    raw = secrets.token_urlsafe(32)
    return raw, hash_consent_token(raw)


def hash_consent_token(raw: str) -> str:
    return hmac.new(
        settings.jwt_secret.encode("utf-8"), raw.encode("utf-8"), hashlib.sha256
    ).hexdigest()


def hash_email_domain(email: str) -> str:
    """One-way hash of the email *domain* for VPC funnel diagnostics.

    analytics-spec §4 requires funnel visibility without ever logging the address.
    """
    domain = email.rsplit("@", 1)[-1].strip().lower() if "@" in email else ""
    return hashlib.sha256(f"{settings.jwt_secret}:{domain}".encode()).hexdigest()[:16]


def constant_time_equals(left: str, right: str) -> bool:
    return hmac.compare_digest(left, right)
