"""Scheduled COPPA maintenance tasks (compliance-report LB-3)."""

from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.services import accounts

logger = logging.getLogger("anointed.maintenance")


def run_consent_maintenance(db: Session | None = None) -> tuple[int, int]:
    """Expire stale VPC tokens and purge abandoned under-13 pending accounts."""
    owns_session = db is None
    if owns_session:
        db = SessionLocal()
    try:
        expired = accounts.expire_stale_consent_tokens(db)
        cleaned = accounts.cleanup_abandoned_pending_accounts(db)
        db.commit()
        if expired or cleaned:
            logger.info(
                "Consent maintenance: expired_tokens=%d cleaned_accounts=%d",
                expired,
                cleaned,
            )
        return expired, cleaned
    except Exception:
        db.rollback()
        logger.exception("Consent maintenance failed")
        raise
    finally:
        if owns_session:
            db.close()
