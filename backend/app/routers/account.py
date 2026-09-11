"""Profile, settings, and account deletion — build order B.11 (M-26, M-27, M-29)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from fastapi import APIRouter
from pydantic import Field
from sqlalchemy import select

from app.core.config import settings
from app.core.deps import Context, CurrentUser, DbSession
from app.core.errors import bad_request
from app.models.commerce import PurchaseRecord
from app.models.enums import AgeGroup, Platform, UnlockStatus
from app.models.user import LevelCompletion, SupportRequest
from app.schemas.common import ApiModel, MessageResponse
from app.services import accounts, analytics

router = APIRouter(prefix="/v1/account", tags=["account"])


class ProfileResponse(ApiModel):
    """M-26 profile."""

    id: str
    name: str | None
    age_group: AgeGroup | None
    is_under_13: bool
    account_status: str
    auth_provider: str | None
    levels_completed: int
    highest_level_completed: int
    total_score: int
    has_unlock: bool
    purchase_display_price: str | None
    notifications_opt_in: bool
    member_since: datetime | None
    privacy_policy_url: str
    terms_of_service_url: str
    support_email: str


class SettingsUpdateRequest(ApiModel):
    """M-27 — only server-relevant settings. Text size and dark mode are stored
    on-device because they never need to follow the account across installs."""

    notifications_opt_in: bool | None = None


class DeletionPreviewResponse(ApiModel):
    """M-29a/M-29b: exactly what deletion removes and what is retained."""

    levels_completed: int
    has_unlock: bool
    is_under_13: bool
    removed: list[str]
    retained_anonymized: list[str]
    warning: str


class DeleteAccountRequest(ApiModel):
    confirm: bool = False
    acknowledged_permanent: bool = False


class DeleteAccountResponse(ApiModel):
    deleted: bool
    levels_completed: int
    had_purchase: bool
    account_age_days: int
    message: str


class SupportRequestPayload(ApiModel):
    """M-31 contact form."""

    subject_category: str = Field(default="general", max_length=64)
    message: str = Field(min_length=5, max_length=4000)
    reply_to: str | None = Field(default=None, max_length=255)
    entry_source: str | None = Field(default=None, max_length=64)


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


@router.get("/profile", response_model=ProfileResponse)
def profile(user: CurrentUser, db: DbSession) -> ProfileResponse:
    progress = accounts.ensure_progress(db, user)
    purchase = db.execute(
        select(PurchaseRecord).where(
            PurchaseRecord.user_id == user.id,
            PurchaseRecord.unlock_status == UnlockStatus.UNLOCKED,
        )
    ).scalars().first()

    return ProfileResponse(
        id=str(user.id),
        name=user.name,
        age_group=user.age_group,
        is_under_13=user.is_under_13,
        account_status=str(user.account_status),
        auth_provider=str(user.primary_auth_provider) if user.primary_auth_provider else None,
        levels_completed=progress.levels_completed_count,
        highest_level_completed=progress.highest_level_completed,
        total_score=progress.total_score,
        has_unlock=purchase is not None,
        purchase_display_price=purchase.price_display if purchase else None,
        notifications_opt_in=user.notifications_opt_in,
        member_since=user.created_at,
        privacy_policy_url=settings.privacy_policy_url,
        terms_of_service_url=settings.terms_of_service_url,
        support_email=settings.support_email,
    )


@router.patch("/settings", response_model=ProfileResponse)
def update_settings(
    payload: SettingsUpdateRequest, user: CurrentUser, db: DbSession
) -> ProfileResponse:
    if payload.notifications_opt_in is not None:
        user.notifications_opt_in = payload.notifications_opt_in
    db.flush()
    return profile(user, db)


@router.get("/deletion-preview", response_model=DeletionPreviewResponse)
def deletion_preview(user: CurrentUser, db: DbSession) -> DeletionPreviewResponse:
    progress = accounts.ensure_progress(db, user)
    has_unlock = accounts.has_unlock(db, user.id)

    retained = [
        "An anonymised purchase reference (no name or contact details), kept only so a "
        "refund dispute can be resolved",
        "Usage counts with no link to you, so overall game statistics stay accurate",
        "A record that a deletion happened, with no personal details in it",
    ]
    warning = (
        "Deleting your account will permanently remove all your progress, scores, and "
        "data. This cannot be undone."
    )
    if user.is_under_13:
        warning += " Your child's data will be permanently removed from our servers immediately."

    return DeletionPreviewResponse(
        levels_completed=progress.levels_completed_count,
        has_unlock=has_unlock,
        is_under_13=user.is_under_13,
        removed=[
            "Your name, mobile number, and age",
            "Your Google or Apple sign-in link",
            "All level progress and scores",
            "Your leaderboard entries",
            "The parental permission record, if there is one",
            "Any support messages you sent",
        ],
        retained_anonymized=retained,
        warning=warning,
    )


@router.post("/delete", response_model=DeleteAccountResponse)
def delete_account(
    payload: DeleteAccountRequest, user: CurrentUser, db: DbSession, context: Context
) -> DeleteAccountResponse:
    """M-29c — hard delete. Apple App Store Review Guidelines §5.1.1(v).

    Both flags are required so a single stray request cannot destroy an account:
    ``confirm`` is M-29a's destructive button, ``acknowledged_permanent`` is the
    M-29b checkbox.
    """
    if not payload.confirm or not payload.acknowledged_permanent:
        raise bad_request(
            "confirmation_required",
            "Please confirm that you understand this is permanent.",
        )

    analytics.track(
        db,
        "account_deletion_started",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={"is_under_13": user.is_under_13},
    )

    summary = accounts.delete_account(db, user, initiated_by="user")

    # Emitted with user=None because the account no longer exists; the event still
    # carries the non-identifying churn fields analytics-spec §10 asks for.
    analytics.track(
        db,
        "account_deleted",
        user=None,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "levels_completed": summary["levels_completed"],
            "had_purchase": summary["had_purchase"],
            "account_age_days": summary["account_age_days"],
            "is_under_13": summary["is_under_13"],
        },
    )

    return DeleteAccountResponse(
        deleted=True,
        levels_completed=summary["levels_completed"],
        had_purchase=summary["had_purchase"],
        account_age_days=summary["account_age_days"],
        message="Your account has been deleted.",
    )


@router.post("/support", response_model=MessageResponse)
def submit_support_request(
    payload: SupportRequestPayload, user: CurrentUser, db: DbSession, context: Context
) -> MessageResponse:
    """M-31 contact form.

    Always persisted first so the operator has the request even when the outbound
    email provider is unconfigured or failing.
    """
    request_row = SupportRequest(
        user_id=user.id,
        subject_category=payload.subject_category,
        message=payload.message,
        reply_to=payload.reply_to,
        app_version=context.app_version,
        entry_source=payload.entry_source,
    )
    db.add(request_row)
    db.flush()

    from app.integrations.email import email_client

    body = (
        f"Support request from user {user.id}\n"
        f"Category: {payload.subject_category}\n"
        f"App version: {context.app_version or 'unknown'}\n"
        f"Entry source: {payload.entry_source or 'unknown'}\n"
        f"Reply to: {payload.reply_to or 'not provided'}\n\n"
        f"{payload.message}"
    )
    try:
        request_row.delivered = email_client.send(
            to=settings.support_email,
            subject=f"[Anointed] {payload.subject_category} — {user.id}",
            html=f"<pre>{body}</pre>",
            text=body,
        )
    except Exception:  # noqa: BLE001 - delivery failure must not lose the request
        request_row.delivered = False

    analytics.track(
        db,
        "support_contact_sent",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "subject_category": payload.subject_category,
            "entry_source": payload.entry_source,
        },
    )

    return MessageResponse(
        code="support_request_received",
        message="Thanks — we've got your message and will reply by email.",
    )


class FaqItem(ApiModel):
    id: str
    category: str
    question: str
    answer: str


class FaqResponse(ApiModel):
    items: list[FaqItem]
    support_email: str
    app_version_note: str


# OQ-07 resolved for v1 as server-hosted rather than hardcoded in the app: FAQ copy
# can then be corrected without an app store release, which matters most for the
# account-recovery answer. Noted as an assumption in the scaffold README.
_FAQ_ITEMS: list[FaqItem] = [
    FaqItem(
        id="play-how",
        category="Playing the game",
        question="How do I finish a level?",
        answer=(
            "Answer all 10 questions correctly before the timer runs out. If you get one "
            "wrong, the level starts again with a fresh set of questions."
        ),
    ),
    FaqItem(
        id="play-answers",
        category="Playing the game",
        question="Why don't you show me the right answer?",
        answer=(
            "We keep the answers hidden so every replay is a real challenge. Try Practice "
            "mode to explore the same levels without any pressure."
        ),
    ),
    FaqItem(
        id="play-practice",
        category="Playing the game",
        question="What is Practice mode?",
        answer=(
            "Practice mode works without internet and has no ads, no scores, and no "
            "leaderboard. All 100 levels are available there."
        ),
    ),
    FaqItem(
        id="account-newdevice",
        category="Account & sign-in",
        question="How do I get my progress back on a new phone?",
        answer=(
            "Use the same sign-in method you used before:\n\n"
            "• Google or Apple — tap the same provider button. Your progress restores automatically.\n"
            "• Phone number — enter the exact same mobile number and display name you used when "
            "you signed up. Spelling and spacing must match.\n\n"
            "If phone sign-in still fails, tap Help & Support from the sign-in screen and choose "
            "Account and sign-in. Include your mobile number and the name on the account so we "
            "can locate it."
        ),
    ),
    FaqItem(
        id="account-phone",
        category="Account & sign-in",
        question="Why doesn't my phone number sign-in work?",
        answer=(
            "Phone accounts are matched by mobile number plus the display name you chose at "
            "sign-up — there is no SMS code. Check that both fields match exactly. If you "
            "originally signed up with Google or Apple, use that button instead. Still stuck? "
            "Contact support with your number and name."
        ),
    ),
    FaqItem(
        id="account-delete",
        category="Account & sign-in",
        question="How do I delete my account?",
        answer=(
            "Open Profile, then Delete my account. This permanently removes your progress "
            "and personal information."
        ),
    ),
    FaqItem(
        id="purchase-what",
        category="Purchases",
        question="What does the purchase unlock?",
        answer=(
            "One payment unlocks levels 6 to 100 forever. Levels 1 to 5 are always free, "
            "and Practice mode is always free."
        ),
    ),
    FaqItem(
        id="purchase-restore",
        category="Purchases",
        question="I already paid but the levels are locked.",
        answer=(
            "Open Settings and tap Restore purchase. Make sure you're signed in to the "
            "same store account you paid with."
        ),
    ),
    FaqItem(
        id="privacy-kids",
        category="Privacy",
        question="My child is under 13 — what do you collect?",
        answer=(
            "We ask a parent or guardian for permission first. Players under 13 never see "
            "ads, and the leaderboard shows only a first name and last initial."
        ),
    ),
]


@router.get("/faq", response_model=FaqResponse)
def faq(user: CurrentUser, db: DbSession, context: Context) -> FaqResponse:
    analytics.track(
        db,
        "support_faq_viewed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={"entry_source": "M-31_support"},
    )
    return FaqResponse(
        items=_FAQ_ITEMS,
        support_email=settings.support_email,
        app_version_note="Include your app version when you contact us — it's shown below.",
    )


@router.get("/completions", response_model=list[int])
def completions(user: CurrentUser, db: DbSession) -> list[int]:
    """Level numbers this user has cleared; used to rehydrate the map offline."""
    return [
        row.level_number
        for row in db.execute(
            select(LevelCompletion)
            .where(LevelCompletion.user_id == user.id)
            .order_by(LevelCompletion.level_number)
        )
        .scalars()
        .all()
    ]
