"""User, UserProgress, and auth identity models."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import AccountStatus, AgeGroup, AuthProvider
from app.models.types import UuidPk, new_uuid


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)

    # PII — all of these are cleared by the account-deletion service.
    mobile: Mapped[str | None] = mapped_column(String(32), index=True)
    name: Mapped[str | None] = mapped_column(String(120))
    age: Mapped[int | None] = mapped_column(Integer)

    age_group: Mapped[AgeGroup | None] = mapped_column(String(16))
    is_under_13: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    account_status: Mapped[AccountStatus] = mapped_column(
        String(40), default=AccountStatus.CONSENTED, nullable=False, index=True
    )
    primary_auth_provider: Mapped[AuthProvider | None] = mapped_column(String(16))

    privacy_accepted_at = timestamp_column(nullable=True)
    privacy_policy_version: Mapped[str | None] = mapped_column(String(32))
    child_notice_acknowledged_at = timestamp_column(nullable=True)

    notifications_opt_in: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    install_id: Mapped[str | None] = mapped_column(String(64), index=True)

    created_at = timestamp_column(default=utcnow, nullable=False)
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)
    last_session_at = timestamp_column(nullable=True)
    account_deleted_at = timestamp_column(nullable=True)

    identities: Mapped[list[AuthIdentity]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    progress: Mapped[UserProgress | None] = relationship(
        back_populates="user", cascade="all, delete-orphan", uselist=False
    )

    __table_args__ = (Index("ix_users_mobile_name", "mobile", "name"),)

    @property
    def can_play(self) -> bool:
        """Pending-consent and denied accounts have no gameplay access (§11)."""
        return self.account_status == AccountStatus.CONSENTED and self.account_deleted_at is None

    @property
    def leaderboard_display_name(self) -> str:
        """Under-13 users show first name + last initial only (design-spec §21, COPPA-06)."""
        raw = (self.name or "").strip()
        if not raw:
            return "Player"
        if not self.is_under_13:
            return raw
        parts = raw.split()
        if len(parts) == 1:
            return parts[0]
        return f"{parts[0]} {parts[-1][0]}."


class AuthIdentity(Base):
    """One row per linked OAuth provider account.

    Kept separate from ``User`` so a user can hold both Google and Apple links and
    so deletion can drop provider subject identifiers independently of the profile.
    """

    __tablename__ = "auth_identities"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    provider: Mapped[AuthProvider] = mapped_column(String(16), nullable=False)
    provider_subject: Mapped[str] = mapped_column(String(255), nullable=False)
    provider_email: Mapped[str | None] = mapped_column(String(255))
    created_at = timestamp_column(default=utcnow, nullable=False)

    user: Mapped[User] = relationship(back_populates="identities")

    __table_args__ = (
        UniqueConstraint("provider", "provider_subject", name="uq_auth_identity_provider_subject"),
    )


class UserProgress(Base):
    __tablename__ = "user_progress"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    highest_level_completed: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    levels_completed_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_attempt_at = timestamp_column(nullable=True)
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)

    user: Mapped[User] = relationship(back_populates="progress")

    @property
    def current_level(self) -> int:
        return self.highest_level_completed + 1


class LevelCompletion(Base):
    """Which levels a user has cleared. Drives the level map's per-node state."""

    __tablename__ = "level_completions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    level_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    best_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    attempts_taken: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    first_completed_at = timestamp_column(default=utcnow, nullable=False)
    last_completed_at = timestamp_column(default=utcnow, nullable=False)


class SupportRequest(Base):
    """M-31 contact form submissions.

    Persisted so the operator still has the request when the outbound email
    provider is unconfigured or transiently failing.
    """

    __tablename__ = "support_requests"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    subject_category: Mapped[str] = mapped_column(String(64), nullable=False)
    message: Mapped[str] = mapped_column(String(4000), nullable=False)
    reply_to: Mapped[str | None] = mapped_column(String(255))
    app_version: Mapped[str | None] = mapped_column(String(32))
    entry_source: Mapped[str | None] = mapped_column(String(64))
    delivered: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at = timestamp_column(default=utcnow, nullable=False)


class RateLimitCounter(Base):
    """Fixed-window counters for signup and attempt-start limits (design-spec §21).

    Stored in Postgres rather than an in-process dict so limits hold across the
    multiple worker processes a Railway/Render deploy runs.
    """

    __tablename__ = "rate_limit_counters"

    scope: Mapped[str] = mapped_column(String(64), primary_key=True)
    key: Mapped[str] = mapped_column(String(255), primary_key=True)
    window_start: Mapped[datetime] = timestamp_column(primary_key=True)
    count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
