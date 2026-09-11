"""VPC service — parental consent record lifecycle (design-spec §11)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import generate_consent_token, hash_consent_token
from app.integrations.email import email_client
from app.models.consent import ParentalConsentRecord
from app.models.enums import AccountStatus, ConsentMethod, ConsentStatus
from app.models.user import User
from app.services import audit


def active_record(db: Session, child_user_id) -> ParentalConsentRecord | None:
    """Most recent consent record for a child, whatever its status."""
    return db.execute(
        select(ParentalConsentRecord)
        .where(ParentalConsentRecord.child_user_id == child_user_id)
        .order_by(ParentalConsentRecord.created_at.desc())
    ).scalars().first()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def grant_consent(
    db: Session,
    child: User,
    record: ParentalConsentRecord,
    *,
    method: ConsentMethod,
    policy_version: str,
) -> None:
    """Mark consent verified and move the child account to ``consented``."""
    record.method = method
    record.status = ConsentStatus.VERIFIED
    record.consented_at = _now()
    record.consent_policy_version = policy_version
    record.verification_token_hash = None  # single-use: burn it on success
    child.account_status = AccountStatus.CONSENTED

    audit.record(
        db,
        "parental_consent_verified",
        actor_type="parent",
        actor_id=record.parent_oauth_sub or record.parent_email,
        target_user_id=str(child.id),
        target_is_under_13=child.is_under_13,
        detail={
            "method": str(method),
            "relationship": str(record.parent_relationship)
            if record.parent_relationship
            else None,
            "policy_version": policy_version,
        },
    )


def deny_consent(db: Session, child: User, record: ParentalConsentRecord) -> None:
    record.status = ConsentStatus.DENIED
    record.denied_at = _now()
    record.verification_token_hash = None
    child.account_status = AccountStatus.CONSENT_DENIED
    audit.record(
        db,
        "parental_consent_denied",
        actor_type="parent",
        actor_id=record.parent_email,
        target_user_id=str(child.id),
        target_is_under_13=child.is_under_13,
        detail={"method": str(record.method)},
    )


def issue_email_challenge(
    db: Session, child: User, parent_email: str
) -> tuple[ParentalConsentRecord, str, bool]:
    """Create or refresh a Path B record and send the verification link.

    Returns ``(record, raw_token, email_sent)``. A new token invalidates the prior
    one (design-spec §11 resend rule).
    """
    record = active_record(db, child.id)
    if record is None or record.status in {ConsentStatus.EXPIRED, ConsentStatus.DENIED}:
        record = ParentalConsentRecord(
            child_user_id=child.id, method=ConsentMethod.EMAIL_PLUS_CONFIRMATION
        )
        db.add(record)
        db.flush()

    raw_token, token_hash = generate_consent_token()
    record.method = ConsentMethod.EMAIL_PLUS_CONFIRMATION
    record.status = ConsentStatus.PENDING
    record.parent_email = parent_email
    record.verification_token_hash = token_hash
    record.send_count += 1
    record.last_sent_at = _now()
    record.expires_at = _now() + timedelta(hours=settings.consent_token_ttl_hours)
    record.consent_policy_version = settings.consent_policy_version
    if child.account_status in {
        AccountStatus.CONSENT_EXPIRED,
        AccountStatus.CONSENT_DENIED,
    }:
        child.account_status = AccountStatus.PENDING_PARENTAL_CONSENT
    db.flush()

    link = f"{settings.web_base_url.rstrip('/')}/consent/verify/{raw_token}"
    sent = email_client.send(
        to=parent_email,
        subject="Please confirm permission for your child to use Anointed",
        html=_email_html(child_name=child.name, link=link),
        text=_email_text(child_name=child.name, link=link),
    )

    audit.record(
        db,
        "parental_consent_email_sent",
        actor_type="system",
        target_user_id=str(child.id),
        target_is_under_13=child.is_under_13,
        detail={
            "send_count": record.send_count,
            "delivered_by_provider": sent,
            "expires_at": record.expires_at.isoformat(),
        },
    )
    return record, raw_token, sent


def resolve_token(db: Session, raw_token: str) -> tuple[ParentalConsentRecord, User] | None:
    """Look up a Path B record by token hash, expiring it if the window has passed."""
    token_hash = hash_consent_token(raw_token)
    record = db.execute(
        select(ParentalConsentRecord).where(
            ParentalConsentRecord.verification_token_hash == token_hash
        )
    ).scalars().first()
    if record is None:
        return None

    expires_at = _aware(record.expires_at)
    if expires_at and expires_at < _now():
        record.status = ConsentStatus.EXPIRED
        record.verification_token_hash = None
        child = db.get(User, record.child_user_id)
        if child and child.account_status == AccountStatus.PENDING_PARENTAL_CONSENT:
            child.account_status = AccountStatus.CONSENT_EXPIRED
        return None

    child = db.get(User, record.child_user_id)
    if child is None:
        return None
    return record, child


def resend_available_at(record: ParentalConsentRecord | None) -> datetime | None:
    if record is None or record.last_sent_at is None:
        return None
    last_sent = _aware(record.last_sent_at)
    return last_sent + timedelta(seconds=settings.consent_resend_cooldown_seconds)


def can_resend(record: ParentalConsentRecord | None) -> tuple[bool, int]:
    """Enforce the 60s cooldown. Returns ``(allowed, seconds_remaining)``."""
    available_at = resend_available_at(record)
    if available_at is None:
        return True, 0
    remaining = int((available_at - _now()).total_seconds())
    return (remaining <= 0), max(remaining, 0)


def sends_today(record: ParentalConsentRecord | None) -> int:
    """Send count within the current token's life, used for the daily cap."""
    return record.send_count if record else 0


# Parent-facing consent copy below and on M-06F is COPPA-oriented draft language.
# Counsel must review and replace before US launch (compliance C-10). The mechanism
# (token issuance, 72h expiry, single-use, audit trail, state machine) is complete.
def _email_text(*, child_name: str | None, link: str) -> str:
    child = child_name or "your child"
    return (
        f"Hello,\n\n"
        f"{child} would like to use Anointed, a Bible character quiz game for children.\n\n"
        f"Because {child} is under 13, U.S. law requires us to obtain verifiable parental "
        f"consent before we collect or use their information.\n\n"
        f"Please open this link on your own device to review what we collect, what we do "
        f"not collect (including no ads for under-13 players), and to give or decline permission:\n"
        f"{link}\n\n"
        f"This link can only be used once and expires in "
        f"{settings.consent_token_ttl_hours} hours.\n\n"
        f"Privacy Policy: {settings.privacy_policy_url}\n"
        f"If you did not expect this email, you can ignore it and no account will be activated.\n\n"
        f"— The Anointed team"
    )


def _email_html(*, child_name: str | None, link: str) -> str:
    child = child_name or "your child"
    return f"""<!doctype html>
<html><body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#1C1A17;">
  <h2 style="color:#6B4FA0;">Permission needed for {child}</h2>
  <p>{child} would like to use <strong>Anointed</strong>, a Bible character quiz game
     for children.</p>
  <p>Because {child} is under 13, U.S. law requires us to obtain verifiable parental
     consent before we collect or use their information.</p>
  <p>Please review what we collect on the next page — including that under-13 players
     see no advertising — then give or decline permission.</p>
  <p style="margin:28px 0;">
    <a href="{link}" style="background:#C8851A;color:#fff;padding:14px 24px;
       border-radius:12px;text-decoration:none;font-weight:700;">
      Review and give permission
    </a>
  </p>
  <p style="font-size:13px;color:#6B6560;">
    This link can only be used once and expires in {settings.consent_token_ttl_hours} hours.<br>
    <a href="{settings.privacy_policy_url}">Privacy Policy</a><br>
    If you did not expect this email you can ignore it — no account will be activated.
  </p>
</body></html>"""
