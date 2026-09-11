"""PurchaseRecord and AdImpressionLog."""

from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import AdFormat, Store, UnlockStatus
from app.models.types import JsonB, UuidPk, new_uuid


class PurchaseRecord(Base):
    __tablename__ = "purchase_records"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)

    # Nullable so an anonymised receipt reference can be retained for refund
    # disputes after the user's account is deleted (design-spec §9).
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )

    store: Mapped[Store] = mapped_column(String(16), nullable=False)
    product_id: Mapped[str] = mapped_column(String(160), nullable=False)
    transaction_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    original_transaction_id: Mapped[str | None] = mapped_column(String(255), index=True)

    # Receipt payload is the store's own token; cleared on account deletion,
    # leaving the non-PII transaction reference behind.
    receipt_token: Mapped[str | None] = mapped_column(Text)
    validation_payload: Mapped[dict] = mapped_column(JsonB, default=dict, nullable=False)

    unlock_status: Mapped[UnlockStatus] = mapped_column(
        String(16), default=UnlockStatus.PENDING, nullable=False, index=True
    )
    validated_at = timestamp_column(nullable=True)
    validated_by_provider: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    price_display: Mapped[str | None] = mapped_column(String(32))
    created_at = timestamp_column(default=utcnow, nullable=False)

    def __str__(self) -> str:
        return f"{self.store}:{self.transaction_id}"


class AdImpressionLog(Base):
    """Separate from AnalyticsEvent for ad-network reconciliation (analytics-spec §14.5)."""

    __tablename__ = "ad_impression_logs"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    ad_unit_id: Mapped[str | None] = mapped_column(String(160))
    ad_format: Mapped[AdFormat] = mapped_column(String(16), default=AdFormat.INTERSTITIAL)
    placement: Mapped[str | None] = mapped_column(String(64))
    is_child_directed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ad_personalized: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    clicked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    level_id: Mapped[int | None] = mapped_column(Integer)
    impressed_at = timestamp_column(default=utcnow, nullable=False, index=True)
