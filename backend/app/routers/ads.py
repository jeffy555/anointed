"""Ads — build order B.8. 13+ only, frequency-capped; under-13 is entirely ad-free."""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter

from app.core.deps import ConsentedUser, Context, DbSession
from app.core.errors import forbidden
from app.models.commerce import AdImpressionLog
from app.models.enums import AdFormat, Platform
from app.schemas.common import ApiModel
from app.services import ads as ads_service, analytics

router = APIRouter(prefix="/v1/ads", tags=["ads"])


class AdConfigResponse(ApiModel):
    ads_enabled: bool
    tag_for_child_directed_treatment: bool
    personalized_ads: bool
    app_id: str | None
    interstitial_unit_id: str | None
    every_nth_level: int
    max_per_session: int
    min_level: int


class AdEventRequest(ApiModel):
    event: Literal["viewed", "clicked"]
    ad_unit_id: str | None = None
    ad_format: AdFormat = AdFormat.INTERSTITIAL
    placement: str = "M-21_ad_break"
    level_id: int | None = None


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


@router.get("/config", response_model=AdConfigResponse)
def ad_config(user: ConsentedUser, context: Context) -> AdConfigResponse:
    """Client asks the server whether to initialise the ad SDK at all.

    Under-13 accounts get ``ads_enabled: false`` and no unit ids, so a client that
    ignores the flag still has nothing to request an ad with.

    In production, ads also stay disabled until ``ADMOB_PRODUCTION_ACK=true`` after
    completing ``docs/admob_coppa_checklist.md``. Live AdMob account settings still
    require human verification (C-11).
    """
    return AdConfigResponse(**ads_service.ad_config_for(user, context.platform))


@router.post("/events", response_model=AdConfigResponse)
def record_ad_event(
    payload: AdEventRequest, user: ConsentedUser, db: DbSession, context: Context
) -> AdConfigResponse:
    """Mirror an AdMob impression/click into ``AdImpressionLog`` and analytics.

    Rejects outright for under-13 accounts: such an event means the client showed an
    ad it never should have, and silently logging it would bury a compliance bug.
    """
    if not ads_service.ads_allowed_for_user(user):
        raise forbidden(
            "ads_not_permitted", "Ads are not shown on this account."
        )

    db.add(
        AdImpressionLog(
            user_id=user.id,
            ad_unit_id=payload.ad_unit_id,
            ad_format=payload.ad_format,
            placement=payload.placement,
            is_child_directed=user.is_under_13,
            ad_personalized=not user.is_under_13,
            clicked=payload.event == "clicked",
            level_id=payload.level_id,
        )
    )

    analytics.track(
        db,
        "ad_viewed" if payload.event == "viewed" else "ad_clicked",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "ad_unit_id": payload.ad_unit_id,
            "ad_format": str(payload.ad_format),
            "ad_personalized": not user.is_under_13,
            "placement": payload.placement,
        },
    )

    return AdConfigResponse(**ads_service.ad_config_for(user, context.platform))
