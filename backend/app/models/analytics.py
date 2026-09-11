"""AnalyticsEvent, AuditLog, and AdminUser."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import Boolean, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import AdminRole, Platform
from app.models.types import JsonB, UuidPk, new_uuid


class AnalyticsEvent(Base):
    """Primary analytics store (analytics-spec §1).

    ``user_id`` is nullable because account deletion nullifies it rather than
    deleting rows — aggregate funnel counts stay valid while the link to a person
    is removed (analytics-spec §15).
    """

    __tablename__ = "analytics_events"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    event_name: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    timestamp_utc = timestamp_column(default=utcnow, nullable=False, index=True)

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    admin_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("admin_users.id", ondelete="SET NULL"), index=True
    )
    session_id: Mapped[str | None] = mapped_column(String(64), index=True)

    age_group: Mapped[str | None] = mapped_column(String(16))
    is_under_13: Mapped[bool | None] = mapped_column(Boolean)
    platform: Mapped[Platform | None] = mapped_column(String(16))
    app_version: Mapped[str | None] = mapped_column(String(32))
    os_version: Mapped[str | None] = mapped_column(String(64))
    device_type: Mapped[str | None] = mapped_column(String(16))

    properties: Mapped[dict[str, Any]] = mapped_column(JsonB, default=dict, nullable=False)

    __table_args__ = (
        Index("ix_analytics_event_name_time", "event_name", "timestamp_utc"),
        Index("ix_analytics_user_event", "user_id", "event_name"),
    )


class AuditLog(Base):
    """Immutable compliance trail for access/export/deletion of user data (architecture §4.5).

    Kept separate from AnalyticsEvent because these rows are compliance records
    rather than product telemetry, and they are exempt from the deletion sweep
    that nullifies ``AnalyticsEvent.user_id``.
    """

    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    action: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    # Plain columns, not FKs: these must survive deletion of the referenced rows.
    actor_type: Mapped[str] = mapped_column(String(16), nullable=False)
    actor_id: Mapped[str | None] = mapped_column(String(64))
    target_user_id: Mapped[str | None] = mapped_column(String(64), index=True)
    target_is_under_13: Mapped[bool | None] = mapped_column(Boolean)

    detail: Mapped[dict[str, Any]] = mapped_column(JsonB, default=dict, nullable=False)
    occurred_at = timestamp_column(default=utcnow, nullable=False, index=True)

    def __str__(self) -> str:
        return f"{self.occurred_at:%Y-%m-%d %H:%M} {self.action}"


class AdminUser(Base):
    __tablename__ = "admin_users"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[AdminRole] = mapped_column(String(16), default=AdminRole.EDITOR, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    failed_login_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_login_at = timestamp_column(nullable=True)
    created_at = timestamp_column(default=utcnow, nullable=False)

    def __str__(self) -> str:
        return self.email
