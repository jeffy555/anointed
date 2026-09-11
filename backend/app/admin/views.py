"""AdminJS-equivalent resource views (A-01 through A-13).

Mapping to design-spec §23 is one-to-one; see the scaffold README for why this is
SQLAdmin rather than AdminJS itself.
"""

from __future__ import annotations

import uuid
from typing import Any

from sqladmin import ModelView, action
from sqlalchemy import select
from starlette.requests import Request
from starlette.responses import RedirectResponse

from app.admin.auth import current_admin_email, current_admin_id
from app.core.database import SessionLocal
from app.models.analytics import AdminUser, AnalyticsEvent, AuditLog
from app.models.commerce import AdImpressionLog, PurchaseRecord
from app.models.consent import ParentalConsentRecord
from app.models.content import BibleCharacter, ContentPublishRecord, Level, Question
from app.models.enums import AttemptStatus, ReviewStatus
from app.models.gameplay import LeaderboardEntry, LevelAttempt
from app.models.user import User
from app.services import analytics, audit


def _log_admin_event(
    request: Request, event_name: str, properties: dict[str, Any]
) -> None:
    """Write an admin analytics event in its own committed transaction.

    analytics-spec §15 wants admin events written transactionally with their action.
    SQLAdmin owns the session for CRUD, so these hooks open their own and commit
    immediately rather than leaving a dangling row.
    """
    with SessionLocal() as db:
        analytics.track(
            db,
            event_name,
            admin_user_id=current_admin_id(request),
            platform="web_admin",
            properties=properties,
        )
        db.commit()


def _changed_fields(data: dict) -> list[str]:
    return sorted(key for key in data if not key.startswith("_"))


class BaseAdminView(ModelView):
    page_size = 50
    page_size_options = [25, 50, 100, 200]


# ------------------------------------------------------------------ A-03 / A-04
class BibleCharacterAdmin(BaseAdminView, model=BibleCharacter):
    name = "Bible Character"
    name_plural = "Bible Characters"
    icon = "fa-solid fa-user"
    category = "Content"

    column_list = [
        BibleCharacter.name,
        BibleCharacter.testament,
        BibleCharacter.review_status,
        BibleCharacter.image_asset_key,
        BibleCharacter.updated_at,
    ]
    column_searchable_list = [BibleCharacter.name, BibleCharacter.description]
    column_sortable_list = [
        BibleCharacter.name,
        BibleCharacter.testament,
        BibleCharacter.review_status,
        BibleCharacter.updated_at,
    ]
    form_columns = [
        BibleCharacter.name,
        BibleCharacter.description,
        BibleCharacter.testament,
        BibleCharacter.era_tags,
        BibleCharacter.image_asset_key,
        BibleCharacter.image_alt_text,
        BibleCharacter.review_status,
    ]

    async def on_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        # design-spec §17G: alt text is required whenever an image is attached,
        # and the editor must block the save rather than warn.
        if data.get("image_asset_key") and not str(data.get("image_alt_text") or "").strip():
            raise ValueError(
                "Image alt text is required when an image asset key is set "
                "(screen-reader accessibility)."
            )
        if is_created:
            data["created_by"] = current_admin_email(request)

    async def after_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        if is_created:
            _log_admin_event(
                request,
                "admin_character_created",
                {
                    "character_id": str(model.id),
                    "level_associations": [],
                    "has_image": bool(model.image_asset_key),
                },
            )
        else:
            _log_admin_event(
                request,
                "admin_character_updated",
                {"character_id": str(model.id), "fields_changed": _changed_fields(data)},
            )

    async def on_model_delete(self, model: Any, request: Request) -> None:
        with SessionLocal() as db:
            linked = db.execute(
                select(Question.id).where(Question.linked_character_id == model.id).limit(1)
            ).first()
        if linked is not None:
            raise ValueError(
                "This character still has questions linked to it. Delete or re-link "
                "those questions first."
            )

    async def after_model_delete(self, model: Any, request: Request) -> None:
        _log_admin_event(
            request,
            "admin_character_deleted",
            {"character_id": str(model.id), "had_linked_questions": False},
        )


# ------------------------------------------------------------------ A-05 / A-06
class QuestionAdmin(BaseAdminView, model=Question):
    name = "Question"
    name_plural = "Questions"
    icon = "fa-solid fa-circle-question"
    category = "Content"

    column_list = [
        Question.level_id,
        Question.question_text,
        Question.variant_type,
        Question.difficulty_tier,
        Question.review_status,
        Question.active,
        Question.updated_at,
    ]
    column_searchable_list = [Question.question_text, Question.correct_answer]
    column_sortable_list = [
        Question.level_id,
        Question.variant_type,
        Question.difficulty_tier,
        Question.review_status,
        Question.active,
        Question.updated_at,
    ]
    form_columns = [
        Question.level,
        Question.character,
        Question.question_text,
        Question.variant_type,
        Question.answer_options,
        Question.correct_answer,
        Question.difficulty_tier,
        Question.verse_reference,
        Question.verse_excerpt,
        Question.image_asset_key,
        Question.image_alt_text,
        Question.review_status,
        Question.active,
    ]

    async def on_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        variant = str(data.get("variant_type") or "text_qa")
        options = data.get("answer_options") or []
        if isinstance(options, str):
            options = [line.strip() for line in options.splitlines() if line.strip()]
            data["answer_options"] = options

        if len(options) != 4:
            raise ValueError("Exactly 4 answer options are required for v1 question types.")

        correct = str(data.get("correct_answer") or "").strip()
        if correct not in options:
            raise ValueError("The correct answer must exactly match one of the four options.")

        if variant == "verse_clue" and not (
            str(data.get("verse_reference") or "").strip()
            and str(data.get("verse_excerpt") or "").strip()
        ):
            raise ValueError(
                "verse_clue questions need both a verse reference and a verse excerpt."
            )

        if variant == "image_clue" and not str(data.get("image_asset_key") or "").strip():
            raise ValueError("image_clue questions need an image asset key.")

        if data.get("image_asset_key") and not str(data.get("image_alt_text") or "").strip():
            raise ValueError("Image alt text is required when an image asset is set.")

        # design-spec §17F three-state gate: a question can only go live after review.
        if data.get("active") and str(data.get("review_status")) != ReviewStatus.APPROVED:
            raise ValueError(
                "A question can only be set active after its review status is 'approved'."
            )

        if is_created:
            data["created_by"] = current_admin_email(request)

    async def after_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        if is_created:
            _log_admin_event(
                request,
                "admin_question_created",
                {
                    "question_id": str(model.id),
                    "level_id": model.level_id,
                    "question_type": str(model.variant_type),
                    "character_id": str(model.linked_character_id),
                },
            )
        else:
            _log_admin_event(
                request,
                "admin_question_updated",
                {"question_id": str(model.id), "fields_changed": _changed_fields(data)},
            )

    async def after_model_delete(self, model: Any, request: Request) -> None:
        _log_admin_event(
            request,
            "admin_question_deleted",
            {"question_id": str(model.id), "level_id": model.level_id},
        )

    @action(
        name="approve_questions",
        label="Mark approved",
        confirmation_message="Mark the selected questions as approved?",
        add_in_detail=True,
        add_in_list=True,
    )
    async def approve_questions(self, request: Request) -> RedirectResponse:
        ids = request.query_params.getlist("pks")
        with SessionLocal() as db:
            for raw in ids:
                question = db.get(Question, uuid.UUID(raw))
                if question is not None:
                    question.review_status = ReviewStatus.APPROVED
                    analytics.track(
                        db,
                        "admin_question_updated",
                        admin_user_id=current_admin_id(request),
                        platform="web_admin",
                        properties={
                            "question_id": raw,
                            "fields_changed": ["review_status"],
                        },
                    )
            db.commit()
        return RedirectResponse(request.url_for("admin:list", identity=self.identity), 302)

    @action(
        name="activate_questions",
        label="Set active (approved only)",
        confirmation_message="Put the selected approved questions into live gameplay?",
        add_in_detail=True,
        add_in_list=True,
    )
    async def activate_questions(self, request: Request) -> RedirectResponse:
        ids = request.query_params.getlist("pks")
        with SessionLocal() as db:
            for raw in ids:
                question = db.get(Question, uuid.UUID(raw))
                # Silently skipping unapproved questions is intentional: a bulk
                # action must not be able to bypass the review gate.
                if question is not None and question.review_status == ReviewStatus.APPROVED:
                    question.active = True
                    analytics.track(
                        db,
                        "admin_question_updated",
                        admin_user_id=current_admin_id(request),
                        platform="web_admin",
                        properties={"question_id": raw, "fields_changed": ["active"]},
                    )
            db.commit()
        return RedirectResponse(request.url_for("admin:list", identity=self.identity), 302)


# ------------------------------------------------------------------------ A-07
class LevelAdmin(BaseAdminView, model=Level):
    name = "Level"
    name_plural = "Levels"
    icon = "fa-solid fa-layer-group"
    category = "Content"

    column_list = [
        Level.level_number,
        Level.title,
        Level.difficulty_tier,
        Level.timer_seconds,
        Level.min_questions_required,
        Level.is_free_tier,
        Level.updated_at,
    ]
    column_sortable_list = [Level.level_number, Level.difficulty_tier, Level.timer_seconds]
    form_columns = [
        Level.level_number,
        Level.title,
        Level.timer_seconds,
        Level.difficulty_tier,
        Level.min_questions_required,
        Level.is_free_tier,
        Level.variant_mix_targets,
    ]
    can_delete = False  # The 100 levels are fixed for v1; deleting one orphans questions.

    async def after_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        _log_admin_event(
            request,
            "admin_level_configured",
            {"level_id": model.level_number, "fields_changed": _changed_fields(data)},
        )


# ------------------------------------------------------------------------ §19
class ContentPublishRecordAdmin(BaseAdminView, model=ContentPublishRecord):
    name = "Content Publish"
    name_plural = "Content Publishes"
    icon = "fa-solid fa-upload"
    category = "Content"

    column_list = [
        ContentPublishRecord.content_version,
        ContentPublishRecord.published_at,
        ContentPublishRecord.published_by,
        ContentPublishRecord.pack_size_bytes,
        ContentPublishRecord.change_summary,
    ]
    column_details_exclude_list = [ContentPublishRecord.pack_json]
    can_create = False
    can_edit = False
    can_delete = False  # content_version must stay monotonic (§19).


# ------------------------------------------------------------------ A-08 / A-09
class UserAdmin(BaseAdminView, model=User):
    name = "Player"
    name_plural = "Players"
    icon = "fa-solid fa-users"
    category = "Players"

    column_list = [
        User.id,
        User.name,
        User.age_group,
        User.is_under_13,
        User.account_status,
        User.primary_auth_provider,
        User.created_at,
        User.last_session_at,
    ]
    column_searchable_list = [User.name, User.mobile]
    column_sortable_list = [User.created_at, User.last_session_at, User.account_status]
    column_formatters = {User.mobile: lambda model, _: _mask_mobile(model.mobile)}
    column_formatters_detail = {User.mobile: lambda model, _: _mask_mobile(model.mobile)}
    can_create = False
    can_edit = False  # Player PII is read-only in admin; deletion is the only write.

    async def on_model_delete(self, model: Any, request: Request) -> None:
        """A-09 admin-initiated deletion runs the same hard-delete path as the app.

        Letting SQLAdmin issue a plain DELETE would leave analytics rows, purchase
        records, and leaderboard entries pointing at a vanished user instead of
        being anonymised, so the real service is invoked here and the ORM delete
        that follows becomes a no-op.
        """
        from app.services.accounts import delete_account

        with SessionLocal() as db:
            user = db.get(User, model.id)
            if user is None:
                return
            is_under_13 = user.is_under_13
            delete_account(
                db,
                user,
                initiated_by="admin",
                actor_id=str(current_admin_id(request) or "admin"),
            )
            analytics.track(
                db,
                "admin_user_deleted",
                admin_user_id=current_admin_id(request),
                platform="web_admin",
                properties={
                    "target_user_id": str(model.id),
                    "target_is_under_13": is_under_13,
                    "initiated_by": "admin",
                },
            )
            db.commit()

    async def on_model_change(
        self, data: dict, model: Any, is_created: bool, request: Request
    ) -> None:
        _log_admin_event(
            request,
            "admin_user_viewed",
            {
                "target_user_id": str(getattr(model, "id", "")),
                "target_is_under_13": bool(getattr(model, "is_under_13", False)),
            },
        )


def _mask_mobile(value: str | None) -> str:
    """A-08 requires the mobile column masked in admin list/detail views."""
    if not value:
        return "—"
    digits = value.lstrip("+")
    if len(digits) <= 4:
        return "*" * len(digits)
    return f"{'*' * (len(digits) - 4)}{digits[-4:]}"


class ParentalConsentAdmin(BaseAdminView, model=ParentalConsentRecord):
    name = "Parental Consent"
    name_plural = "Parental Consents"
    icon = "fa-solid fa-shield-halved"
    category = "Players"

    column_list = [
        ParentalConsentRecord.child_user_id,
        ParentalConsentRecord.method,
        ParentalConsentRecord.status,
        ParentalConsentRecord.parent_guardian_name,
        ParentalConsentRecord.parent_relationship,
        ParentalConsentRecord.consented_at,
        ParentalConsentRecord.expires_at,
    ]
    column_sortable_list = [
        ParentalConsentRecord.status,
        ParentalConsentRecord.consented_at,
        ParentalConsentRecord.created_at,
    ]
    # The token hash is a credential, not reporting data; keep it out of the UI.
    column_details_exclude_list = [ParentalConsentRecord.verification_token_hash]
    can_create = False
    can_edit = False
    can_delete = False


# ------------------------------------------------------------------------- §21
class LevelAttemptAdmin(BaseAdminView, model=LevelAttempt):
    name = "Level Attempt"
    name_plural = "Level Attempts"
    icon = "fa-solid fa-gamepad"
    category = "Gameplay"

    column_list = [
        LevelAttempt.id,
        LevelAttempt.user_id,
        LevelAttempt.level_id,
        LevelAttempt.mode,
        LevelAttempt.status,
        LevelAttempt.suspicious,
        LevelAttempt.computed_score,
        LevelAttempt.started_at,
    ]
    column_sortable_list = [
        LevelAttempt.started_at,
        LevelAttempt.status,
        LevelAttempt.computed_score,
        LevelAttempt.level_id,
    ]
    can_create = False
    can_edit = False
    can_delete = False

    @action(
        name="invalidate_attempt",
        label="Invalidate & remove from leaderboard",
        confirmation_message=(
            "Mark the selected attempts invalid and revoke their leaderboard entries?"
        ),
        add_in_detail=True,
        add_in_list=True,
    )
    async def invalidate_attempt(self, request: Request) -> RedirectResponse:
        """Custom action from design-spec §23 / §21 suspicious-activity handling."""
        ids = request.query_params.getlist("pks")
        admin_id = current_admin_id(request)
        with SessionLocal() as db:
            for raw in ids:
                attempt = db.get(LevelAttempt, uuid.UUID(raw))
                if attempt is None:
                    continue
                attempt.status = AttemptStatus.INVALID
                attempt.suspicious = True
                attempt.invalidated_by = str(admin_id or "admin")
                entries = (
                    db.execute(
                        select(LeaderboardEntry).where(LeaderboardEntry.attempt_id == attempt.id)
                    )
                    .scalars()
                    .all()
                )
                for entry in entries:
                    entry.revoked = True
                audit.record(
                    db,
                    "leaderboard_attempt_invalidated",
                    actor_type="admin",
                    actor_id=str(admin_id) if admin_id else "admin",
                    target_user_id=str(attempt.user_id),
                    detail={
                        "attempt_id": raw,
                        "level_id": attempt.level_id,
                        "entries_revoked": len(entries),
                    },
                )
            db.commit()
        return RedirectResponse(request.url_for("admin:list", identity=self.identity), 302)


class LeaderboardEntryAdmin(BaseAdminView, model=LeaderboardEntry):
    name = "Leaderboard Entry"
    name_plural = "Leaderboard Entries"
    icon = "fa-solid fa-trophy"
    category = "Gameplay"

    column_list = [
        LeaderboardEntry.display_name,
        LeaderboardEntry.score,
        LeaderboardEntry.level_id,
        LeaderboardEntry.is_under_13,
        LeaderboardEntry.revoked,
        LeaderboardEntry.recorded_at,
    ]
    column_sortable_list = [LeaderboardEntry.score, LeaderboardEntry.recorded_at]
    can_create = False
    can_edit = False


class PurchaseRecordAdmin(BaseAdminView, model=PurchaseRecord):
    name = "Purchase"
    name_plural = "Purchases"
    icon = "fa-solid fa-receipt"
    category = "Gameplay"

    column_list = [
        PurchaseRecord.created_at,
        PurchaseRecord.user_id,
        PurchaseRecord.store,
        PurchaseRecord.product_id,
        PurchaseRecord.transaction_id,
        PurchaseRecord.unlock_status,
        PurchaseRecord.validated_by_provider,
    ]
    column_sortable_list = [PurchaseRecord.created_at, PurchaseRecord.unlock_status]
    # The raw receipt is a store credential; never render it in the browser.
    column_details_exclude_list = [PurchaseRecord.receipt_token, PurchaseRecord.validation_payload]
    can_create = False
    can_edit = False
    can_delete = False


class AdImpressionAdmin(BaseAdminView, model=AdImpressionLog):
    name = "Ad Impression"
    name_plural = "Ad Impressions"
    icon = "fa-solid fa-rectangle-ad"
    category = "Gameplay"

    column_list = [
        AdImpressionLog.impressed_at,
        AdImpressionLog.placement,
        AdImpressionLog.ad_format,
        AdImpressionLog.clicked,
        AdImpressionLog.is_child_directed,
        AdImpressionLog.level_id,
    ]
    column_sortable_list = [AdImpressionLog.impressed_at]
    can_create = False
    can_edit = False
    can_delete = False


# ------------------------------------------------------------------------ A-12
class AuditLogAdmin(BaseAdminView, model=AuditLog):
    name = "Audit Log"
    name_plural = "Audit Log"
    icon = "fa-solid fa-clipboard-list"
    category = "Compliance"

    column_list = [
        AuditLog.occurred_at,
        AuditLog.action,
        AuditLog.actor_type,
        AuditLog.actor_id,
        AuditLog.target_user_id,
        AuditLog.target_is_under_13,
    ]
    column_searchable_list = [AuditLog.action, AuditLog.target_user_id]
    column_sortable_list = [AuditLog.occurred_at, AuditLog.action]
    # Immutable by construction — the compliance value of this table is that no
    # operator, including an admin, can edit or remove entries.
    can_create = False
    can_edit = False
    can_delete = False


class AnalyticsEventAdmin(BaseAdminView, model=AnalyticsEvent):
    name = "Analytics Event"
    name_plural = "Analytics Events"
    icon = "fa-solid fa-chart-line"
    category = "Compliance"

    column_list = [
        AnalyticsEvent.timestamp_utc,
        AnalyticsEvent.event_name,
        AnalyticsEvent.platform,
        AnalyticsEvent.user_id,
        AnalyticsEvent.admin_user_id,
        AnalyticsEvent.age_group,
    ]
    column_searchable_list = [AnalyticsEvent.event_name]
    column_sortable_list = [AnalyticsEvent.timestamp_utc, AnalyticsEvent.event_name]
    can_create = False
    can_edit = False
    can_delete = False


# ------------------------------------------------------------------------ A-13
class AdminUserAdmin(BaseAdminView, model=AdminUser):
    name = "Admin User"
    name_plural = "Admin Users"
    icon = "fa-solid fa-user-shield"
    category = "Settings"

    column_list = [
        AdminUser.email,
        AdminUser.role,
        AdminUser.is_active,
        AdminUser.last_login_at,
        AdminUser.created_at,
    ]
    form_columns = [AdminUser.email, AdminUser.role, AdminUser.is_active]
    # password_hash is never exposed in a form; use the Change password page.
    column_details_exclude_list = [AdminUser.password_hash]


ALL_VIEWS = [
    BibleCharacterAdmin,
    QuestionAdmin,
    LevelAdmin,
    ContentPublishRecordAdmin,
    UserAdmin,
    ParentalConsentAdmin,
    LevelAttemptAdmin,
    LeaderboardEntryAdmin,
    PurchaseRecordAdmin,
    AdImpressionAdmin,
    AuditLogAdmin,
    AnalyticsEventAdmin,
    AdminUserAdmin,
]
