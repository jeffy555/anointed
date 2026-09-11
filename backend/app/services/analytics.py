"""Analytics ingestion.

``track()`` is the single write path into ``AnalyticsEvent`` for both server-side
events and events forwarded from the mobile client. Envelope shape follows
analytics-spec §2.
"""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.models.analytics import AnalyticsEvent
from app.models.enums import AccountStatus, Platform
from app.models.user import User

# analytics-spec §4 pending-consent guardrail: an account awaiting VPC may only
# produce onboarding/VPC telemetry. Anything gameplay-, ad-, purchase-, or
# leaderboard-shaped is dropped server-side too, so a client bug cannot create
# PII-linked events for a child whose parent has not consented yet.
CONSENT_PENDING_ALLOWED_EVENTS: frozenset[str] = frozenset(
    {
        "session_start",
        "screen_view",
        "force_upgrade_shown",
        "sign_up_started",
        "sign_up_completed",
        "sign_in_completed",
        "sign_out_completed",
        "age_gate_triggered",
        "vpc_parent_gate_viewed",
        "vpc_path_selected",
        "vpc_parent_oauth_completed",
        "vpc_attestation_submitted",
        "vpc_email_requested",
        "vpc_email_verified",
        "vpc_consent_denied",
        "parental_consent_completed",
        "child_privacy_notice_acknowledged",
        "account_deletion_started",
        "account_deleted",
        "support_faq_viewed",
        "support_contact_sent",
    }
)

# Events that must never carry a user link for under-13 accounts even once
# consented. Ads are never served to under-13 users at all (§20), so an ad event
# arriving for one is a client bug; dropping it is the safe behaviour.
UNDER_13_FORBIDDEN_EVENTS: frozenset[str] = frozenset({"ad_viewed", "ad_clicked"})

_PII_KEYS = {"mobile", "phone", "name", "email", "parent_email", "display_name"}


def sanitize_properties(properties: dict[str, Any] | None) -> dict[str, Any]:
    """Strip anything that looks like PII before an event is persisted.

    analytics-spec §2 forbids mobile number, name, or email in the event stream.
    Enforcing it here means a careless call site cannot leak them.
    """
    if not properties:
        return {}
    return {key: value for key, value in properties.items() if key.lower() not in _PII_KEYS}


def is_event_allowed(event_name: str, user: User | None) -> bool:
    if user is None:
        return True
    if user.account_status == AccountStatus.PENDING_PARENTAL_CONSENT:
        return event_name in CONSENT_PENDING_ALLOWED_EVENTS
    if user.is_under_13 and event_name in UNDER_13_FORBIDDEN_EVENTS:
        return False
    return True


def track(
    db: Session,
    event_name: str,
    *,
    user: User | None = None,
    admin_user_id: uuid.UUID | None = None,
    session_id: str | None = None,
    platform: Platform | str | None = None,
    app_version: str | None = None,
    os_version: str | None = None,
    device_type: str | None = None,
    properties: dict[str, Any] | None = None,
) -> AnalyticsEvent | None:
    """Record one analytics event. Returns None when policy drops the event.

    The row is added to the caller's session but not committed, so an event and
    the action it describes commit together (analytics-spec §15 requires this for
    admin events, and it is the right default everywhere).
    """
    if not is_event_allowed(event_name, user):
        return None

    event = AnalyticsEvent(
        event_name=event_name,
        user_id=user.id if user else None,
        admin_user_id=admin_user_id,
        session_id=session_id,
        age_group=str(user.age_group) if user and user.age_group else None,
        is_under_13=user.is_under_13 if user else None,
        platform=platform if platform else (Platform.SERVER if user is None else None),
        app_version=app_version,
        os_version=os_version,
        device_type=device_type,
        properties=sanitize_properties(properties),
    )
    db.add(event)
    return event
