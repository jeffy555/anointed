"""FastAPI dependencies: request context, session auth, and the consent gate."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import TokenError, decode_session_token
from app.models.enums import AccountStatus
from app.models.user import User

DbSession = Annotated[Session, Depends(get_db)]


@dataclass(frozen=True)
class RequestContext:
    """Client metadata used for analytics envelopes and abuse controls."""

    install_id: str | None
    client_ip: str | None
    app_version: str | None
    os_version: str | None
    device_type: str | None
    platform: str | None
    session_id: str | None


def get_request_context(
    request: Request,
    x_install_id: Annotated[str | None, Header(alias="X-Install-Id")] = None,
    x_app_version: Annotated[str | None, Header(alias="X-App-Version")] = None,
    x_os_version: Annotated[str | None, Header(alias="X-OS-Version")] = None,
    x_device_type: Annotated[str | None, Header(alias="X-Device-Type")] = None,
    x_platform: Annotated[str | None, Header(alias="X-Platform")] = None,
    x_session_id: Annotated[str | None, Header(alias="X-Session-Id")] = None,
) -> RequestContext:
    return RequestContext(
        install_id=x_install_id,
        client_ip=_client_ip(request),
        app_version=x_app_version,
        os_version=x_os_version,
        device_type=x_device_type,
        platform=x_platform,
        session_id=x_session_id,
    )


def _client_ip(request: Request) -> str | None:
    # Railway and Render both terminate TLS at a proxy, so the socket peer is the
    # proxy; the left-most X-Forwarded-For entry is the original client.
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


Context = Annotated[RequestContext, Depends(get_request_context)]


def _bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        return None
    return token.strip()


def get_current_user_optional(
    db: DbSession,
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> User | None:
    token = _bearer_token(authorization)
    if not token:
        return None
    try:
        claims = decode_session_token(token)
        user_id = uuid.UUID(claims["sub"])
    except (TokenError, KeyError, ValueError):
        return None
    user = db.get(User, user_id)
    if user is None or user.account_deleted_at is not None:
        return None
    return user


def get_current_user(
    user: Annotated[User | None, Depends(get_current_user_optional)],
) -> User:
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "not_authenticated", "message": "Sign in to continue."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def get_consented_user(user: Annotated[User, Depends(get_current_user)]) -> User:
    """Gate for everything a pending-consent account must not reach.

    design-spec §11: while an under-13 account is ``pending_parental_consent``
    there is no gameplay, no ads, and no PII-linked analytics. Enforced here so
    every gameplay/leaderboard/IAP route inherits it rather than re-checking.
    """
    if user.age is None:
        # An OAuth account exists before the age gate has been answered. Until it
        # is, we cannot know whether VPC applies, so nothing gameplay-shaped opens.
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "profile_incomplete",
                "message": "Finish setting up your profile first.",
                "account_status": str(user.account_status),
            },
        )

    if user.account_status == AccountStatus.CONSENTED:
        return user

    reason_by_status = {
        AccountStatus.PENDING_PARENTAL_CONSENT: (
            "consent_pending",
            "A parent or guardian needs to finish giving permission first.",
        ),
        AccountStatus.CONSENT_EXPIRED: (
            "consent_expired",
            "The parent permission link expired. Please start again.",
        ),
        AccountStatus.CONSENT_DENIED: (
            "consent_denied",
            "A parent or guardian declined permission for this account.",
        ),
        AccountStatus.ABANDONED_PENDING_CLEANUP: (
            "consent_abandoned",
            "This account was closed because permission was never completed.",
        ),
    }
    code, message = reason_by_status.get(
        user.account_status, ("account_unavailable", "This account can't play right now.")
    )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={"code": code, "message": message, "account_status": str(user.account_status)},
    )


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_current_user_optional)]
ConsentedUser = Annotated[User, Depends(get_consented_user)]
