"""Audit log writes for compliance-relevant actions on user data (architecture §4.5)."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.models.analytics import AuditLog


def record(
    db: Session,
    action: str,
    *,
    actor_type: str,
    actor_id: str | uuid.UUID | None = None,
    target_user_id: str | uuid.UUID | None = None,
    target_is_under_13: bool | None = None,
    detail: dict[str, Any] | None = None,
) -> AuditLog:
    """Append one immutable audit row.

    Added to the caller's session so the audit entry and the action it records
    commit or roll back together — an admin deletion that cannot write its audit
    row must not delete anything.
    """
    entry = AuditLog(
        action=action,
        actor_type=actor_type,
        actor_id=str(actor_id) if actor_id else None,
        target_user_id=str(target_user_id) if target_user_id else None,
        target_is_under_13=target_is_under_13,
        detail=detail or {},
    )
    db.add(entry)
    return entry
