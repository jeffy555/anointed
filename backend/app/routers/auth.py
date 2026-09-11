"""Auth — build order B.1. Google, Apple, and phone (no SMS OTP)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import Context, CurrentUser, DbSession
from app.core.errors import bad_request, conflict, not_found, too_many_requests
from app.core.security import create_session_token
from app.integrations.oauth import verifier_for
from app.models.enums import AccountStatus, AuthProvider, Platform
from app.models.user import AuthIdentity, User
from app.schemas.auth import (
    AuthResponse,
    OAuthSignInRequest,
    PhoneSignInRequest,
    PhoneSignUpRequest,
    PrivacyAcceptRequest,
    ProfileCompletionRequest,
    SessionResponse,
    SessionUser,
)
from app.schemas.common import MessageResponse
from app.services import accounts, analytics, audit, ratelimit

router = APIRouter(prefix="/v1/auth", tags=["auth"])


def session_user(db: Session, user: User) -> SessionUser:
    progress = accounts.ensure_progress(db, user)
    return SessionUser(
        id=str(user.id),
        name=user.name,
        age=user.age,
        age_group=user.age_group,
        is_under_13=user.is_under_13,
        account_status=user.account_status,
        primary_auth_provider=user.primary_auth_provider,
        privacy_accepted=user.privacy_accepted_at is not None,
        child_notice_acknowledged=user.child_notice_acknowledged_at is not None,
        notifications_opt_in=user.notifications_opt_in,
        has_unlock=accounts.has_unlock(db, user.id),
        highest_level_completed=progress.highest_level_completed,
        levels_completed_count=progress.levels_completed_count,
    )


def _auth_response(
    db: Session, user: User, *, is_new_account: bool, install_id: str | None
) -> AuthResponse:
    return AuthResponse(
        session_token=create_session_token(user.id, install_id=install_id),
        user=session_user(db, user),
        next_step=accounts.next_onboarding_step(db, user),
        is_new_account=is_new_account,
    )


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


@router.post("/oauth", response_model=AuthResponse)
def oauth_sign_in(
    payload: OAuthSignInRequest, db: DbSession, context: Context
) -> AuthResponse:
    """Verify a Google/Apple ID token, then create or restore the account.

    An OAuth sign-in on a new device restores the existing account automatically
    (design-spec §9), which is why this single endpoint serves both M-03 and M-10.
    """
    identity = verifier_for(payload.provider).verify(payload.id_token)
    user = accounts.find_by_provider(db, payload.provider, identity.subject)
    is_new_account = user is None

    if user is None:
        user = User(
            name=(payload.name or identity.name or "").strip() or None,
            primary_auth_provider=AuthProvider(payload.provider),
            install_id=context.install_id,
            account_status=AccountStatus.CONSENTED,
        )
        db.add(user)
        db.flush()
        db.add(
            AuthIdentity(
                user_id=user.id,
                provider=AuthProvider(payload.provider),
                provider_subject=identity.subject,
                provider_email=identity.email,
            )
        )
        if payload.age is not None:
            accounts.apply_age(user, payload.age)
        db.flush()
        accounts.ensure_progress(db, user)
        analytics.track(
            db,
            "sign_up_started",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            app_version=context.app_version,
            properties={"auth_method": payload.provider},
        )
    else:
        if payload.name and not user.name:
            user.name = payload.name.strip()
        if payload.age is not None and user.age is None:
            accounts.apply_age(user, payload.age)
        analytics.track(
            db,
            "sign_in_completed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            app_version=context.app_version,
            properties={
                "auth_method": payload.provider,
                "is_new_device": bool(
                    context.install_id and context.install_id != user.install_id
                ),
            },
        )
        if context.install_id:
            user.install_id = context.install_id

    user.last_session_at = datetime.now(timezone.utc)

    if is_new_account and user.age is not None and user.is_under_13:
        analytics.track(
            db,
            "age_gate_triggered",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={"auth_method": payload.provider, "routed_to_vpc": True},
        )

    return _auth_response(db, user, is_new_account=is_new_account, install_id=context.install_id)


@router.post("/phone/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def phone_sign_up(
    payload: PhoneSignUpRequest, db: DbSession, context: Context
) -> AuthResponse:
    """M-04 phone sign-up: mobile + name + age, no OTP.

    Rate-limited by install id and client IP (design-spec §21) because there is no
    SMS verification standing between a script and unlimited account creation.
    """
    for scope, key, limit in (
        (
            "phone_signup_install",
            context.install_id,
            settings.phone_signups_per_install_per_day,
        ),
        ("phone_signup_ip", context.client_ip, settings.phone_signups_per_ip_per_day),
    ):
        result = ratelimit.check_and_increment(
            db, scope, key, limit=limit, window=timedelta(days=1)
        )
        if not result.allowed:
            raise too_many_requests(
                "signup_rate_limited",
                "Too many accounts have been created from this device today. Try again tomorrow.",
                result.retry_after_seconds,
            )

    if accounts.find_by_phone(db, payload.mobile, payload.name) is not None:
        raise conflict(
            "account_exists",
            "An account already exists with that number and name. Try signing in instead.",
        )

    user = User(
        mobile=payload.mobile,
        name=payload.name,
        primary_auth_provider=AuthProvider.PHONE,
        install_id=context.install_id,
        account_status=AccountStatus.CONSENTED,
    )
    db.add(user)
    db.flush()
    accounts.apply_age(user, payload.age)
    accounts.ensure_progress(db, user)
    user.last_session_at = datetime.now(timezone.utc)

    analytics.track(
        db,
        "sign_up_started",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        app_version=context.app_version,
        properties={"auth_method": "phone"},
    )
    if user.is_under_13:
        analytics.track(
            db,
            "age_gate_triggered",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={"auth_method": "phone", "routed_to_vpc": True},
        )

    return _auth_response(db, user, is_new_account=True, install_id=context.install_id)


@router.post("/phone/signin", response_model=AuthResponse)
def phone_sign_in(
    payload: PhoneSignInRequest, db: DbSession, context: Context
) -> AuthResponse:
    """M-10 phone sign-in: mobile + name match, no OTP (accepted v1 tradeoff, OQ-13)."""
    result = ratelimit.check_and_increment(
        db, "phone_signin_ip", context.client_ip, limit=30, window=timedelta(hours=1)
    )
    if not result.allowed:
        raise too_many_requests(
            "signin_rate_limited",
            "Too many sign-in attempts. Please wait a few minutes.",
            result.retry_after_seconds,
        )

    user = accounts.find_by_phone(db, payload.mobile, payload.name)
    if user is None:
        raise not_found(
            "account_not_found",
            "We couldn't find that account. Check your number or sign up.",
        )

    analytics.track(
        db,
        "sign_in_completed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        app_version=context.app_version,
        properties={
            "auth_method": "phone",
            "is_new_device": bool(context.install_id and context.install_id != user.install_id),
        },
    )
    if context.install_id:
        user.install_id = context.install_id
    user.last_session_at = datetime.now(timezone.utc)

    return _auth_response(db, user, is_new_account=False, install_id=context.install_id)


@router.post("/profile", response_model=AuthResponse)
def complete_profile(
    payload: ProfileCompletionRequest, user: CurrentUser, db: DbSession, context: Context
) -> AuthResponse:
    """Age capture for the OAuth path (design-spec §3 step 3), then M-05 routing."""
    if user.age is not None:
        raise conflict("profile_already_set", "This profile is already complete.")

    user.name = payload.name
    accounts.apply_age(user, payload.age)
    db.flush()

    if user.is_under_13:
        analytics.track(
            db,
            "age_gate_triggered",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "auth_method": str(user.primary_auth_provider or "google"),
                "routed_to_vpc": True,
            },
        )

    return _auth_response(db, user, is_new_account=False, install_id=context.install_id)


@router.post("/privacy-accept", response_model=SessionResponse)
def accept_privacy(
    payload: PrivacyAcceptRequest, user: CurrentUser, db: DbSession, context: Context
) -> SessionResponse:
    """M-08 privacy policy + ToS acknowledgment; 'Continue' is acceptance."""
    if not payload.accepted:
        raise bad_request(
            "privacy_not_accepted", "You need to accept the terms to use Anointed."
        )

    if user.is_under_13 and user.account_status != AccountStatus.CONSENTED:
        raise bad_request(
            "consent_required",
            "A parent or guardian needs to finish giving permission first.",
        )

    first_acceptance = user.privacy_accepted_at is None
    user.privacy_accepted_at = datetime.now(timezone.utc)
    user.privacy_policy_version = settings.consent_policy_version
    db.flush()

    if first_acceptance:
        analytics.track(
            db,
            "sign_up_completed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            app_version=context.app_version,
            properties={
                "auth_method": str(user.primary_auth_provider or "phone"),
                "age_group": str(user.age_group) if user.age_group else None,
                "parental_consent_required": user.is_under_13,
                "parental_consent_granted": user.account_status == AccountStatus.CONSENTED,
            },
        )
        audit.record(
            db,
            "privacy_terms_accepted",
            actor_type="user",
            actor_id=str(user.id),
            target_user_id=str(user.id),
            target_is_under_13=user.is_under_13,
            detail={"policy_version": settings.consent_policy_version},
        )

    return SessionResponse(
        user=session_user(db, user), next_step=accounts.next_onboarding_step(db, user)
    )


@router.get("/session", response_model=SessionResponse)
def current_session(user: CurrentUser, db: DbSession, context: Context) -> SessionResponse:
    """M-01 session routing. Also records session_start for DAU."""
    now = datetime.now(timezone.utc)
    analytics.track(
        db,
        "session_start",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        app_version=context.app_version,
        os_version=context.os_version,
        device_type=context.device_type,
        properties={
            "is_new_user": user.privacy_accepted_at is None,
            "launch_source": "cold_launch",
            "auth_provider_linked": str(user.primary_auth_provider or "none"),
            "account_status": str(user.account_status),
            "connectivity": "online",
        },
    )
    user.last_session_at = now
    return SessionResponse(
        user=session_user(db, user), next_step=accounts.next_onboarding_step(db, user)
    )


@router.post("/signout", response_model=MessageResponse)
def sign_out(user: CurrentUser, db: DbSession, context: Context) -> MessageResponse:
    """M-30 sign-out.

    Sessions are stateless JWTs, so the client discards its token; this endpoint
    exists to record the intentional session end that analytics-spec §4 asks for.
    """
    analytics.track(
        db,
        "sign_out_completed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
    )
    return MessageResponse(code="signed_out", message="You've been signed out.")
