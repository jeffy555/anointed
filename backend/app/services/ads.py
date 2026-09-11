"""Ad eligibility policy — design-spec §20.

The rules live server-side so an out-of-date client cannot show an interstitial to
an under-13 player. The client still enforces its own session cap because session
state is client-side; the server decides everything age- and level-related.
"""

from __future__ import annotations

from app.core.config import settings
from app.models.enums import AttemptMode
from app.models.user import User


def ads_allowed_for_user(user: User) -> bool:
    """Under-13 players are ad-free and the ad SDK is never initialised for them."""
    return not user.is_under_13


def interstitial_eligible(
    user: User,
    *,
    level_number: int,
    mode: AttemptMode,
    levels_completed_this_session: int,
    ads_shown_this_session: int,
) -> bool:
    """Whether M-21 may be shown after this level completion.

    Every condition from §20: main mode only, 13+ only, never on levels 1-3,
    every 3rd completion in the session, capped at 2 per session.
    """
    if mode != AttemptMode.RANKED:
        return False
    if not ads_allowed_for_user(user):
        return False
    if level_number < settings.ad_min_level:
        return False
    if ads_shown_this_session >= settings.ad_max_per_session:
        return False
    if levels_completed_this_session <= 0:
        return False
    return levels_completed_this_session % settings.ad_every_nth_level == 0


def ad_config_for(user: User, platform: str | None) -> dict:
    """Client ad configuration. Under-13 gets no unit ids at all, not just a flag."""
    disabled = {
        "ads_enabled": False,
        "tag_for_child_directed_treatment": True,
        "personalized_ads": False,
        "app_id": None,
        "interstitial_unit_id": None,
        "every_nth_level": settings.ad_every_nth_level,
        "max_per_session": settings.ad_max_per_session,
        "min_level": settings.ad_min_level,
    }

    if not ads_allowed_for_user(user):
        return disabled

    # Production ads stay off until docs/admob_coppa_checklist.md is completed and
    # ADMOB_PRODUCTION_ACK=true is set (compliance-report C-11).
    if settings.is_production and not settings.admob_production_ack:
        return disabled

    is_ios = (platform or "").lower() == "ios"
    return {
        "ads_enabled": True,
        "tag_for_child_directed_treatment": False,
        "personalized_ads": True,
        "app_id": settings.admob_app_id_ios if is_ios else settings.admob_app_id_android,
        "interstitial_unit_id": (
            settings.admob_interstitial_unit_ios
            if is_ios
            else settings.admob_interstitial_unit_android
        ),
        "every_nth_level": settings.ad_every_nth_level,
        "max_per_session": settings.ad_max_per_session,
        "min_level": settings.ad_min_level,
    }
