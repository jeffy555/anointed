"""Account creation, onboarding routing, and the deletion/anonymisation flow."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.analytics import AnalyticsEvent
from app.models.commerce import AdImpressionLog, PurchaseRecord
from app.models.consent import ParentalConsentRecord
from app.models.enums import (
    AccountStatus,
    ConsentStatus,
    UnlockStatus,
    age_group_for,
)
from app.models.gameplay import (
    LeaderboardEntry,
    LevelAttempt,
    UserPerformanceSummary,
)
from app.models.user import (
    AuthIdentity,
    LevelCompletion,
    SupportRequest,
    User,
    UserProgress,
)
from app.services import audit

# Onboarding step identifiers shared with the mobile router (design-spec §3).
STEP_PROFILE = "profile_completion"
STEP_CONSENT = "parental_consent"
STEP_CHILD_NOTICE = "child_privacy_notice"
STEP_PRIVACY = "privacy_acknowledgment"
STEP_LEVEL_MAP = "level_map"


def apply_age(user: User, age: int) -> None:
    """Set age and everything derived from it, including the consent gate.

    Age routing (M-05) is a server decision so a client cannot skip the VPC flow
    by simply not navigating to it.
    """
    user.age = age
    user.age_group = age_group_for(age)
    user.is_under_13 = age < settings.child_age_threshold
    # Every call site runs while ``user.age`` is still None, i.e. before the account
    # has ever been through the age gate, so no consent can already have been
    # verified. Setting the pending state unconditionally is therefore safe, and it
    # is what stops a fresh account's default ``consented`` status from letting a
    # child straight past the VPC gate.
    if user.is_under_13:
        user.account_status = AccountStatus.PENDING_PARENTAL_CONSENT
    elif user.account_status == AccountStatus.PENDING_PARENTAL_CONSENT:
        user.account_status = AccountStatus.CONSENTED


def ensure_progress(db: Session, user: User) -> UserProgress:
    progress = db.get(UserProgress, user.id)
    if progress is None:
        progress = UserProgress(user_id=user.id)
        db.add(progress)
        db.flush()
    return progress


def has_unlock(db: Session, user_id: uuid.UUID) -> bool:
    """True when the user holds a validated, non-refunded levels 6-100 unlock."""
    return (
        db.execute(
            select(PurchaseRecord.id).where(
                PurchaseRecord.user_id == user_id,
                PurchaseRecord.unlock_status == UnlockStatus.UNLOCKED,
            )
        ).first()
        is not None
    )


def next_onboarding_step(db: Session, user: User) -> str:
    if user.age is None:
        return STEP_PROFILE
    if user.is_under_13:
        if user.account_status in {
            AccountStatus.PENDING_PARENTAL_CONSENT,
            AccountStatus.CONSENT_EXPIRED,
            AccountStatus.CONSENT_DENIED,
            AccountStatus.ABANDONED_PENDING_CLEANUP,
        }:
            return STEP_CONSENT
        if user.child_notice_acknowledged_at is None:
            return STEP_CHILD_NOTICE
    if user.privacy_accepted_at is None:
        return STEP_PRIVACY
    return STEP_LEVEL_MAP


def find_by_provider(db: Session, provider: str, subject: str) -> User | None:
    identity = db.execute(
        select(AuthIdentity).where(
            AuthIdentity.provider == provider, AuthIdentity.provider_subject == subject
        )
    ).scalar_one_or_none()
    if identity is None:
        return None
    user = db.get(User, identity.user_id)
    return user if user and user.account_deleted_at is None else None


def find_by_phone(db: Session, mobile: str, name: str) -> User | None:
    """Phone sign-in match: mobile + name, no OTP (design-spec §10).

    Name comparison is case-insensitive and whitespace-tolerant; requiring an
    exact match would lock users out over capitalisation.
    """
    candidates = (
        db.execute(select(User).where(User.mobile == mobile, User.account_deleted_at.is_(None)))
        .scalars()
        .all()
    )
    target = name.strip().casefold()
    for candidate in candidates:
        if (candidate.name or "").strip().casefold() == target:
            return candidate
    return None


# --------------------------------------------------------------------- deletion
def delete_account(
    db: Session,
    user: User,
    *,
    initiated_by: str,
    actor_id: str | None = None,
) -> dict:
    """Hard-delete PII and anonymise what must be retained (design-spec §9, §15).

    Removed outright: name, mobile, age, install id, OAuth subject identifiers,
    the ParentalConsentRecord, progress, attempts, and support messages.

    Retained anonymised: purchase records with the user link severed and the
    receipt token cleared (refund disputes need the store transaction reference),
    leaderboard entries with the display name replaced, analytics rows with
    ``user_id`` nulled so funnel aggregates stay correct, and the audit trail.
    """
    summary = {
        "levels_completed": 0,
        "had_purchase": has_unlock(db, user.id),
        "account_age_days": 0,
        "is_under_13": user.is_under_13,
    }
    progress = db.get(UserProgress, user.id)
    if progress:
        summary["levels_completed"] = progress.levels_completed_count
    if user.created_at:
        created = user.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        summary["account_age_days"] = (datetime.now(timezone.utc) - created).days

    # Audit first: if this write fails the whole deletion rolls back, so we never
    # delete a minor's data without a compliance record of having done so.
    audit.record(
        db,
        "user_account_deleted",
        actor_type=initiated_by,
        actor_id=actor_id or str(user.id),
        target_user_id=str(user.id),
        target_is_under_13=user.is_under_13,
        detail={
            "levels_completed": summary["levels_completed"],
            "had_purchase": summary["had_purchase"],
            "account_age_days": summary["account_age_days"],
            "initiated_by": initiated_by,
        },
    )

    # Anonymise rows that must outlive the account.
    db.execute(
        update(AnalyticsEvent)
        .where(AnalyticsEvent.user_id == user.id)
        .values(user_id=None, session_id=None)
    )
    db.execute(
        update(LeaderboardEntry)
        .where(LeaderboardEntry.user_id == user.id)
        .values(display_name="Deleted player")
    )
    db.execute(
        update(PurchaseRecord)
        .where(PurchaseRecord.user_id == user.id)
        .values(user_id=None, receipt_token=None, validation_payload={})
    )
    db.execute(
        update(AdImpressionLog).where(AdImpressionLog.user_id == user.id).values(user_id=None)
    )
    db.execute(
        update(SupportRequest).where(SupportRequest.user_id == user.id).values(user_id=None)
    )

    # Delete child rows that are pure PII or pure personal history.
    for model, column in (
        (ParentalConsentRecord, ParentalConsentRecord.child_user_id),
        (AuthIdentity, AuthIdentity.user_id),
        (LevelCompletion, LevelCompletion.user_id),
        (LevelAttempt, LevelAttempt.user_id),
        (UserPerformanceSummary, UserPerformanceSummary.user_id),
        (UserProgress, UserProgress.user_id),
    ):
        for row in db.execute(select(model).where(column == user.id)).scalars().all():
            db.delete(row)

    # LeaderboardEntry rows are anonymised above but keep a FK to users; drop the
    # link so the user row itself can go.
    db.execute(
        update(LeaderboardEntry).where(LeaderboardEntry.user_id == user.id).values(revoked=True)
    )
    for entry in (
        db.execute(select(LeaderboardEntry).where(LeaderboardEntry.user_id == user.id))
        .scalars()
        .all()
    ):
        db.delete(entry)

    db.delete(user)
    db.flush()
    return summary


def cleanup_abandoned_pending_accounts(db: Session) -> int:
    """Purge under-13 accounts whose VPC was never completed (design-spec §11).

    Retention rule: 14 days after sign-up, pending or denied child PII is deleted
    and only a non-PII audit event remains.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=settings.consent_pending_cleanup_days)
    stale = (
        db.execute(
            select(User).where(
                User.account_status.in_(
                    [
                        AccountStatus.PENDING_PARENTAL_CONSENT,
                        AccountStatus.CONSENT_EXPIRED,
                        AccountStatus.CONSENT_DENIED,
                    ]
                ),
                User.created_at < cutoff,
                User.account_deleted_at.is_(None),
            )
        )
        .scalars()
        .all()
    )
    for user in stale:
        audit.record(
            db,
            "pending_consent_account_cleaned_up",
            actor_type="system",
            target_user_id=str(user.id),
            target_is_under_13=user.is_under_13,
            detail={"previous_status": str(user.account_status)},
        )
        delete_account(db, user, initiated_by="system")
    return len(stale)


def expire_stale_consent_tokens(db: Session) -> int:
    """Flip pending Path B records past their 72h window to expired."""
    now = datetime.now(timezone.utc)
    records = (
        db.execute(
            select(ParentalConsentRecord).where(
                ParentalConsentRecord.status == ConsentStatus.PENDING,
                ParentalConsentRecord.expires_at.is_not(None),
                ParentalConsentRecord.expires_at < now,
            )
        )
        .scalars()
        .all()
    )
    for record in records:
        record.status = ConsentStatus.EXPIRED
        record.verification_token_hash = None
        child = db.get(User, record.child_user_id)
        if child and child.account_status == AccountStatus.PENDING_PARENTAL_CONSENT:
            child.account_status = AccountStatus.CONSENT_EXPIRED
    return len(records)
