"""VPC endpoints — build order B.2 (design-spec §11)."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import Context, CurrentUser, DbSession
from app.core.errors import bad_request, conflict, forbidden, too_many_requests
from app.core.security import hash_email_domain
from app.integrations.oauth import verifier_for
from app.models.consent import ParentalConsentRecord
from app.models.enums import AccountStatus, ConsentMethod, ConsentStatus, Platform
from app.models.user import AuthIdentity, User
from app.schemas.auth import SessionResponse
from app.schemas.consent import (
    ChildNoticeAckRequest,
    ConsentStatusResponse,
    ParentEmailRequest,
    ParentOAuthConsentRequest,
    mask_email,
)
from app.services import accounts, analytics, consent as consent_service

router = APIRouter(prefix="/v1/consent", tags=["consent"])


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


def _require_pending_child(user: User) -> None:
    if not user.is_under_13:
        raise conflict(
            "consent_not_required", "This account doesn't need parental permission."
        )
    if user.account_status == AccountStatus.CONSENTED:
        raise conflict("already_consented", "Permission has already been given.")


def _status_response(db: Session, user: User) -> ConsentStatusResponse:
    record = consent_service.active_record(db, user.id)
    return ConsentStatusResponse(
        account_status=str(user.account_status),
        consent_status=record.status if record else None,
        method=record.method if record else None,
        parent_email_masked=mask_email(record.parent_email if record else None),
        expires_at=record.expires_at if record else None,
        can_resend_at=consent_service.resend_available_at(record),
        send_count=record.send_count if record else 0,
        next_step=accounts.next_onboarding_step(db, user),
    )


@router.get("/status", response_model=ConsentStatusResponse)
def consent_status(user: CurrentUser, db: DbSession) -> ConsentStatusResponse:
    """Polled by M-06E every 5 seconds while the parent completes Path B."""
    return _status_response(db, user)


@router.post("/parent-oauth/complete", response_model=SessionResponse)
def complete_parent_oauth(
    payload: ParentOAuthConsentRequest, user: CurrentUser, db: DbSession, context: Context
) -> SessionResponse:
    """VPC Path A — parent OAuth (M-06A) + attestation (M-06B) + child profile (M-06C)."""
    _require_pending_child(user)

    if not payload.is_parent_or_guardian or not payload.consents_to_data_use:
        raise bad_request(
            "attestation_incomplete",
            "Both permission checkboxes must be ticked to continue.",
        )

    parent_identity = verifier_for(payload.parent_provider).verify(payload.parent_id_token)

    # The parent must use their own account, not the child's. design-spec §11 rule 3
    # says to force the account picker in the UI; this is the server-side backstop
    # for the case where the child simply re-authorises with their own account.
    child_subjects = {
        identity.provider_subject
        for identity in db.query(AuthIdentity).filter(AuthIdentity.user_id == user.id).all()
    }
    if parent_identity.subject in child_subjects:
        raise forbidden(
            "parent_account_same_as_child",
            "Please sign in with a parent or guardian's own account, not the child's.",
        )

    record = consent_service.active_record(db, user.id)
    if record is None:
        record = ParentalConsentRecord(
            child_user_id=user.id, method=ConsentMethod.OAUTH_PARENT_ATTESTATION
        )
        db.add(record)
        db.flush()

    record.parent_guardian_name = payload.parent_guardian_name
    record.parent_relationship = payload.parent_relationship
    record.parent_email = parent_identity.email
    record.parent_oauth_provider = payload.parent_provider
    record.parent_oauth_sub = parent_identity.subject

    analytics.track(
        db,
        "vpc_parent_oauth_completed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={"parent_oauth_provider": payload.parent_provider},
    )
    analytics.track(
        db,
        "vpc_attestation_submitted",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "consent_policy_version": settings.consent_policy_version,
            "relationship": str(payload.parent_relationship),
        },
    )

    # M-06C — parent sets the child's display name and optional linking number.
    if payload.child_display_name:
        user.name = payload.child_display_name.strip()
    if payload.child_mobile and not user.mobile:
        user.mobile = payload.child_mobile.strip()

    consent_service.grant_consent(
        db,
        user,
        record,
        method=ConsentMethod.OAUTH_PARENT_ATTESTATION,
        policy_version=settings.consent_policy_version,
    )
    db.flush()

    analytics.track(
        db,
        "parental_consent_completed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "vpc_path": str(ConsentMethod.OAUTH_PARENT_ATTESTATION),
            "consent_granted": True,
        },
    )

    from app.routers.auth import session_user  # local import avoids a circular module

    return SessionResponse(
        user=session_user(db, user), next_step=accounts.next_onboarding_step(db, user)
    )


@router.post("/email/request", response_model=ConsentStatusResponse)
def request_parent_email(
    payload: ParentEmailRequest, user: CurrentUser, db: DbSession, context: Context
) -> ConsentStatusResponse:
    """VPC Path B — M-06D parent email entry; sends the signed 72h link."""
    _require_pending_child(user)

    existing = consent_service.active_record(db, user.id)
    allowed, retry_after = consent_service.can_resend(existing)
    if not allowed:
        raise too_many_requests(
            "resend_cooldown",
            f"Please wait {retry_after} seconds before sending another email.",
            retry_after,
        )
    if consent_service.sends_today(existing) >= settings.consent_max_sends_per_day:
        raise too_many_requests(
            "resend_limit_reached",
            "We've sent the maximum number of permission emails for today.",
            3600,
        )

    record, _raw_token, _sent = consent_service.issue_email_challenge(
        db, user, str(payload.parent_email)
    )

    analytics.track(
        db,
        "vpc_email_requested",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "resend_attempt": record.send_count,
            "email_domain_hash": hash_email_domain(str(payload.parent_email)),
        },
    )

    return _status_response(db, user)


@router.post("/child-notice/acknowledge", response_model=SessionResponse)
def acknowledge_child_notice(
    payload: ChildNoticeAckRequest, user: CurrentUser, db: DbSession, context: Context
) -> SessionResponse:
    """M-07 child privacy notice — shown only after VPC is verified."""
    if user.is_under_13 and user.account_status != AccountStatus.CONSENTED:
        raise forbidden(
            "consent_required",
            "A parent or guardian needs to finish giving permission first.",
        )

    now = datetime.now(timezone.utc)
    user.child_notice_acknowledged_at = now
    record = consent_service.active_record(db, user.id)
    if record and record.status == ConsentStatus.VERIFIED:
        record.child_notice_acknowledged_at = now
    db.flush()

    analytics.track(
        db,
        "child_privacy_notice_acknowledged",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={"acknowledged_by": payload.acknowledged_by},
    )

    from app.routers.auth import session_user

    return SessionResponse(
        user=session_user(db, user), next_step=accounts.next_onboarding_step(db, user)
    )
