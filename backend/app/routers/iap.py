"""IAP — build order B.7. Levels 6-100 unlock at the ~₹49 tier (design-spec §20)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter
from sqlalchemy import select

from app.core.config import settings
from app.core.deps import ConsentedUser, Context, DbSession
from app.core.errors import bad_request, conflict
from app.integrations.iap import apple_iap, google_play_iap
from app.models.commerce import PurchaseRecord
from app.models.enums import Platform, Store, UnlockStatus
from app.schemas.common import ApiModel
from app.services import accounts, analytics, audit

router = APIRouter(prefix="/v1/iap", tags=["iap"])


class ProductResponse(ApiModel):
    """M-22 pricing. The store SDK supplies the localised display price on-device;
    these values are the server-side fallback and the source of truth for the SKU id."""

    product_id: str
    price_display: str
    price_amount_minor: int
    price_currency: str
    unlocks_levels_from: int
    unlocks_levels_to: int
    free_tier_max_level: int
    already_purchased: bool


class ValidateReceiptRequest(ApiModel):
    store: Literal["app_store", "google_play"]
    receipt: str
    product_id: str | None = None
    trigger: Literal["level_5_complete", "locked_level_tap", "restore"] = "locked_level_tap"


class PurchaseStatusResponse(ApiModel):
    has_unlock: bool
    unlock_status: UnlockStatus | None
    store: Store | None
    transaction_id: str | None
    validated_at: datetime | None
    validated_by_provider: bool
    outcome: Literal["success", "nothing_to_restore", "already_owned", "invalid"]


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


@router.get("/product", response_model=ProductResponse)
def product(user: ConsentedUser, db: DbSession) -> ProductResponse:
    return ProductResponse(
        product_id=settings.iap_product_id,
        price_display=settings.iap_price_display,
        price_amount_minor=settings.iap_price_amount_minor,
        price_currency=settings.iap_price_currency,
        unlocks_levels_from=settings.free_tier_max_level + 1,
        unlocks_levels_to=settings.total_levels,
        free_tier_max_level=settings.free_tier_max_level,
        already_purchased=accounts.has_unlock(db, user.id),
    )


@router.get("/status", response_model=PurchaseStatusResponse)
def purchase_status(user: ConsentedUser, db: DbSession) -> PurchaseStatusResponse:
    record = db.execute(
        select(PurchaseRecord)
        .where(
            PurchaseRecord.user_id == user.id,
            PurchaseRecord.unlock_status == UnlockStatus.UNLOCKED,
        )
        .order_by(PurchaseRecord.created_at.desc())
    ).scalars().first()

    if record is None:
        return PurchaseStatusResponse(
            has_unlock=False,
            unlock_status=None,
            store=None,
            transaction_id=None,
            validated_at=None,
            validated_by_provider=False,
            outcome="nothing_to_restore",
        )

    return PurchaseStatusResponse(
        has_unlock=True,
        unlock_status=record.unlock_status,
        store=record.store,
        transaction_id=record.transaction_id,
        validated_at=record.validated_at,
        validated_by_provider=record.validated_by_provider,
        outcome="already_owned",
    )


@router.post("/validate", response_model=PurchaseStatusResponse)
def validate_receipt(
    payload: ValidateReceiptRequest, user: ConsentedUser, db: DbSession, context: Context
) -> PurchaseStatusResponse:
    """Validate a store receipt and grant the unlock.

    Also serves M-25 Restore purchase: the client replays the receipt the store hands
    back from its restore call through this same endpoint.
    """
    store = Store(payload.store)
    if not payload.receipt.strip():
        raise bad_request("receipt_missing", "We didn't receive a purchase receipt.")

    if store == Store.APP_STORE:
        result = apple_iap.validate(payload.receipt)
    else:
        result = google_play_iap.validate(payload.receipt, payload.product_id)
        if result.valid:
            google_play_iap.acknowledge(payload.receipt, payload.product_id)

    if not result.valid:
        analytics.track(
            db,
            "purchase_failed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "store": payload.store,
                "error_code": result.reason or "validation_failed",
                "trigger": payload.trigger,
            },
        )
        return PurchaseStatusResponse(
            has_unlock=accounts.has_unlock(db, user.id),
            unlock_status=None,
            store=store,
            transaction_id=None,
            validated_at=None,
            validated_by_provider=result.validated_by_provider,
            outcome="invalid",
        )

    existing = db.execute(
        select(PurchaseRecord).where(
            PurchaseRecord.store == store, PurchaseRecord.transaction_id == result.transaction_id
        )
    ).scalars().first()

    if existing is not None and existing.user_id not in (None, user.id):
        # One receipt linked to another account — refuse (safe default). Admin can
        # transfer via support if policy allows (see docs/legal/README.md).
        raise conflict(
            "receipt_already_used",
            "That purchase is already linked to another account. Please contact support.",
        )

    now = datetime.now(timezone.utc)
    if existing is None:
        record = PurchaseRecord(
            user_id=user.id,
            store=store,
            product_id=result.product_id or settings.iap_product_id,
            transaction_id=result.transaction_id,
            original_transaction_id=result.original_transaction_id,
            receipt_token=payload.receipt,
            validation_payload=result.raw,
            unlock_status=UnlockStatus.UNLOCKED,
            validated_at=now,
            validated_by_provider=result.validated_by_provider,
            price_display=settings.iap_price_display,
        )
        db.add(record)
    else:
        record = existing
        record.user_id = user.id
        record.unlock_status = UnlockStatus.UNLOCKED
        record.validated_at = now
        record.validated_by_provider = result.validated_by_provider
        record.validation_payload = result.raw

    db.flush()

    was_restore = payload.trigger == "restore"
    if was_restore:
        analytics.track(
            db,
            "purchase_restored",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={"outcome": "success"},
        )
    else:
        analytics.track(
            db,
            "purchase_completed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "store": payload.store,
                "product_id": record.product_id,
                "transaction_id": record.transaction_id,
                "trigger": payload.trigger,
            },
        )

    audit.record(
        db,
        "iap_unlock_granted",
        actor_type="user",
        actor_id=str(user.id),
        target_user_id=str(user.id),
        target_is_under_13=user.is_under_13,
        detail={
            "store": payload.store,
            "transaction_id": record.transaction_id,
            "validated_by_provider": result.validated_by_provider,
        },
    )

    return PurchaseStatusResponse(
        has_unlock=True,
        unlock_status=record.unlock_status,
        store=record.store,
        transaction_id=record.transaction_id,
        validated_at=record.validated_at,
        validated_by_provider=record.validated_by_provider,
        outcome="success",
    )
