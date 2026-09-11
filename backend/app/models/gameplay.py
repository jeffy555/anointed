"""LevelAttempt and LeaderboardEntry — the server-authoritative gameplay record (§21)."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import Boolean, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import AttemptMode, AttemptStatus
from app.models.types import JsonB, UuidPk, new_uuid


class LevelAttempt(Base):
    __tablename__ = "level_attempts"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    level_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    mode: Mapped[AttemptMode] = mapped_column(String(16), default=AttemptMode.RANKED, nullable=False)
    status: Mapped[AttemptStatus] = mapped_column(
        String(16), default=AttemptStatus.IN_PROGRESS, nullable=False, index=True
    )

    # Server-drawn question ids, in order. The client never chooses or reorders these.
    question_sequence: Mapped[list[str]] = mapped_column(JsonB, default=list, nullable=False)
    expected_next_index: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    answers: Mapped[list[dict[str, Any]]] = mapped_column(JsonB, default=list, nullable=False)

    attempt_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    timer_seconds: Mapped[int] = mapped_column(Integer, default=60, nullable=False)
    computed_score: Mapped[int | None] = mapped_column(Integer)

    suspicious: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    rejection_reason: Mapped[str | None] = mapped_column(String(40))
    invalidated_by: Mapped[str | None] = mapped_column(String(160))

    install_id: Mapped[str | None] = mapped_column(String(64), index=True)

    started_at = timestamp_column(default=utcnow, nullable=False)
    completed_at = timestamp_column(nullable=True)
    expires_at = timestamp_column(nullable=False)

    __table_args__ = (Index("ix_level_attempts_user_level", "user_id", "level_id"),)

    def __str__(self) -> str:
        return f"attempt {self.id} L{self.level_id} {self.status}"


class LeaderboardEntry(Base):
    """Written by the server only, on a validated completed ranked attempt.

    There is deliberately no client-facing write endpoint for this table (§21).
    """

    __tablename__ = "leaderboard_entries"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    attempt_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("level_attempts.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    level_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False, index=True)

    # Snapshot of the masked display name at write time so the board can be read
    # without joining to PII, and so it survives account deletion as an anonymised row.
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    is_under_13: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    recorded_at = timestamp_column(default=utcnow, nullable=False, index=True)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)


class UserPerformanceSummary(Base):
    """Rolling per-user/per-level aggregate feeding future adaptive difficulty.

    Shape is specified in analytics-spec §13. Updated after each attempt resolves;
    never on the request's critical path for correctness.
    """

    __tablename__ = "user_performance_summary"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    level_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    age_group: Mapped[str | None] = mapped_column(String(16))
    attempts_total: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    pass_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    answers_total: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_answer_time_ms: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_timer_utilization: Mapped[float] = mapped_column(default=0.0, nullable=False)
    first_try_passes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_updated = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)

    @property
    def avg_time_per_question_ms(self) -> int:
        return int(self.total_answer_time_ms / self.answers_total) if self.answers_total else 0

    @property
    def avg_timer_utilization(self) -> float:
        return self.total_timer_utilization / self.answers_total if self.answers_total else 0.0

    @property
    def first_try_pass_rate(self) -> float:
        return self.first_try_passes / self.attempts_total if self.attempts_total else 0.0
