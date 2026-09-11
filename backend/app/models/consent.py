"""ParentalConsentRecord — the VPC audit record required for under-13 accounts (§11)."""

from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import ConsentMethod, ConsentStatus, ParentRelationship
from app.models.types import UuidPk, new_uuid


class ParentalConsentRecord(Base):
    __tablename__ = "parental_consent_records"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    child_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    method: Mapped[ConsentMethod] = mapped_column(String(40), nullable=False)
    status: Mapped[ConsentStatus] = mapped_column(
        String(16), default=ConsentStatus.PENDING, nullable=False, index=True
    )

    parent_guardian_name: Mapped[str | None] = mapped_column(String(160))
    parent_relationship: Mapped[ParentRelationship | None] = mapped_column(String(16))
    parent_email: Mapped[str | None] = mapped_column(String(255))

    # Path A
    parent_oauth_provider: Mapped[str | None] = mapped_column(String(16))
    parent_oauth_sub: Mapped[str | None] = mapped_column(String(255))

    # Path B — only the hash is stored; the raw token exists solely in the email link.
    verification_token_hash: Mapped[str | None] = mapped_column(String(128), index=True)
    send_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_sent_at = timestamp_column(nullable=True)

    consent_policy_version: Mapped[str | None] = mapped_column(String(32))
    consented_at = timestamp_column(nullable=True)
    denied_at = timestamp_column(nullable=True)
    child_notice_acknowledged_at = timestamp_column(nullable=True)
    expires_at = timestamp_column(nullable=True)

    created_at = timestamp_column(default=utcnow, nullable=False)
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)
