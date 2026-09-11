"""Level map, level detail, and server-authoritative attempts — build order B.4/B.5."""

from __future__ import annotations

import uuid
from datetime import timedelta

from fastapi import APIRouter, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import ConsentedUser, Context, DbSession
from app.core.errors import AppError, not_found, too_many_requests
from app.models.content import Level, Question
from app.models.enums import AttemptMode, AttemptStatus, Platform, VariantType
from app.models.gameplay import LevelAttempt
from app.models.user import LevelCompletion, User, UserProgress
from app.schemas.game import (
    AttemptQuestion,
    AttemptStateResponse,
    LevelDetailResponse,
    LevelMapResponse,
    LevelSummary,
    StartAttemptRequest,
    StartAttemptResponse,
    SubmitAnswerRequest,
    SubmitAnswerResponse,
    TimerExpiredRequest,
)
from app.services import accounts, ads, analytics, gameplay, ratelimit

router = APIRouter(prefix="/v1/game", tags=["game"])


def _platform(context: Context) -> Platform | None:
    valid = {item.value for item in Platform}
    return Platform(context.platform) if context.platform in valid else None


def _gameplay_error(exc: gameplay.GameplayError) -> AppError:
    status_by_code = {
        "level_locked": status.HTTP_403_FORBIDDEN,
        "level_not_reached": status.HTTP_403_FORBIDDEN,
        "insufficient_questions": status.HTTP_409_CONFLICT,
        "attempt_not_active": status.HTTP_409_CONFLICT,
        "question_missing": status.HTTP_500_INTERNAL_SERVER_ERROR,
    }
    return AppError(
        status_by_code.get(exc.code, status.HTTP_400_BAD_REQUEST),
        exc.code,
        exc.message,
        extra=exc.extra or None,
    )


def _variant_types_by_level(db: Session) -> dict[int, list[VariantType]]:
    """All (level, variant_type) pairs in one query.

    Previously ran once per level inside the /levels loop — 100 round trips on a
    100-level map. Invisible against local SQLite, but each trip is a real network
    round trip against Neon, which was turning "load the level map" into a multi-
    second hang. One grouped query instead of a hundred small ones.
    """
    rows = db.execute(
        select(Question.level_id, Question.variant_type)
        .where(
            Question.active.is_(True),
            Question.review_status == "approved",
        )
        .distinct()
    ).all()
    out: dict[int, list[VariantType]] = {}
    for level_id, variant_type in rows:
        out.setdefault(int(level_id), []).append(VariantType(variant_type))
    return out


@router.get("/levels", response_model=LevelMapResponse)
def level_map(user: ConsentedUser, db: DbSession) -> LevelMapResponse:
    """M-11 level map. Lock state is server-computed from progress plus IAP status."""
    has_unlock = accounts.has_unlock(db, user.id)
    progress = accounts.ensure_progress(db, user)
    highest = progress.highest_level_completed

    levels = (
        db.execute(select(Level).order_by(Level.level_number)).scalars().all()
    )
    completions = {
        row.level_number: row
        for row in db.execute(
            select(LevelCompletion).where(LevelCompletion.user_id == user.id)
        )
        .scalars()
        .all()
    }
    pool_counts = _pool_counts(db)
    variant_types = _variant_types_by_level(db)

    summaries: list[LevelSummary] = []
    for level in levels:
        completion = completions.get(level.level_number)
        paywalled = level.level_number > settings.free_tier_max_level and not has_unlock
        beyond_progress = level.level_number > highest + 1
        summaries.append(
            LevelSummary(
                level_number=level.level_number,
                title=level.title,
                difficulty_tier=level.difficulty_tier,
                timer_seconds=level.timer_seconds,
                is_free_tier=level.is_free_tier,
                locked=paywalled or beyond_progress,
                completed=completion is not None,
                best_score=completion.best_score if completion else None,
                is_current=level.level_number == highest + 1,
                playable=pool_counts.get(level.level_number, 0)
                >= settings.questions_per_attempt,
                available_variant_types=variant_types.get(level.level_number, []),
            )
        )

    return LevelMapResponse(
        levels=summaries,
        highest_level_completed=highest,
        current_level=highest + 1,
        has_unlock=has_unlock,
        free_tier_max_level=settings.free_tier_max_level,
        total_levels=settings.total_levels,
    )


def _variant_types(db: Session, level_number: int) -> list[VariantType]:
    """Single-level version, for the level-detail screen — one level, one query,
    no batching needed here (that's only a problem in a loop over all of them)."""
    rows = db.execute(
        select(Question.variant_type)
        .where(
            Question.level_id == level_number,
            Question.active.is_(True),
            Question.review_status == "approved",
        )
        .distinct()
    ).scalars().all()
    return [VariantType(value) for value in rows]


def _pool_counts(db: Session) -> dict[int, int]:
    from sqlalchemy import func

    rows = db.execute(
        select(Question.level_id, func.count())
        .where(Question.active.is_(True), Question.review_status == "approved")
        .group_by(Question.level_id)
    ).all()
    return {int(level_id): int(count) for level_id, count in rows}


@router.get("/levels/{level_number}", response_model=LevelDetailResponse)
def level_detail(
    level_number: int, user: ConsentedUser, db: DbSession
) -> LevelDetailResponse:
    """M-12 level detail card."""
    level = db.get(Level, level_number)
    if level is None:
        raise not_found("level_not_found", "That level doesn't exist.")

    has_unlock = accounts.has_unlock(db, user.id)
    progress = accounts.ensure_progress(db, user)
    completion = db.get(LevelCompletion, (user.id, level_number))
    pool_size = len(gameplay.live_question_pool(db, level_number))

    return LevelDetailResponse(
        level_number=level.level_number,
        title=level.title,
        difficulty_tier=level.difficulty_tier,
        timer_seconds=level.timer_seconds,
        questions_per_attempt=settings.questions_per_attempt,
        is_free_tier=level.is_free_tier,
        locked=(level_number > settings.free_tier_max_level and not has_unlock)
        or level_number > progress.highest_level_completed + 1,
        completed=completion is not None,
        best_score=completion.best_score if completion else None,
        available_variant_types=_variant_types(db, level_number),
        pool_size=pool_size,
        playable=pool_size >= settings.questions_per_attempt,
    )


@router.post(
    "/levels/{level_number}/attempts/start",
    response_model=StartAttemptResponse,
    status_code=status.HTTP_201_CREATED,
)
def start_attempt(
    level_number: int,
    payload: StartAttemptRequest,
    user: ConsentedUser,
    db: DbSession,
    context: Context,
) -> StartAttemptResponse:
    """Open a server-authoritative attempt (§21 step 1).

    Correct answers are never included in the response.
    """
    level = db.get(Level, level_number)
    if level is None:
        raise not_found("level_not_found", "That level doesn't exist.")

    mode = AttemptMode(payload.mode)

    if mode == AttemptMode.RANKED:
        for scope, key, limit in (
            ("attempt_start_user", str(user.id), settings.attempt_starts_per_user_per_hour),
            (
                "attempt_start_install",
                context.install_id,
                settings.attempt_starts_per_install_per_hour,
            ),
        ):
            result = ratelimit.check_and_increment(
                db, scope, key, limit=limit, window=timedelta(hours=1)
            )
            if not result.allowed:
                analytics.track(
                    db,
                    "leaderboard_attempt_rejected",
                    user=user,
                    session_id=context.session_id,
                    platform=_platform(context),
                    properties={
                        "level_id": level_number,
                        "rejection_reason": "rate_limit",
                        "attempt_id": None,
                    },
                )
                raise too_many_requests(
                    "attempt_rate_limited",
                    "You've started a lot of levels recently. Please take a short break.",
                    result.retry_after_seconds,
                )

        try:
            gameplay.assert_can_start(
                db, user, level, has_unlock=accounts.has_unlock(db, user.id)
            )
        except gameplay.GameplayError as exc:
            raise _gameplay_error(exc) from exc

    try:
        attempt, questions, option_map, adjustments = gameplay.start_attempt(
            db, user, level, mode=mode, install_id=context.install_id
        )
    except gameplay.GameplayError as exc:
        raise _gameplay_error(exc) from exc

    analytics.track(
        db,
        "level_started",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        app_version=context.app_version,
        properties={
            "level_id": level_number,
            "difficulty_tier": str(level.difficulty_tier),
            "timer_seconds": attempt.timer_seconds,
            "base_timer_seconds": adjustments.base_timer_seconds,
            "adaptive_profile": adjustments.profile.value,
            "attempt_number": attempt.attempt_number,
            "is_practice_mode": mode == AttemptMode.PRACTICE,
        },
    )

    return StartAttemptResponse(
        attempt_id=str(attempt.id),
        level_number=level_number,
        timer_seconds=attempt.timer_seconds,
        attempt_number=attempt.attempt_number,
        expires_at=attempt.expires_at,
        questions=[
            AttemptQuestion(
                question_index=index,
                question_id=str(question.id),
                variant_type=VariantType(question.variant_type),
                question_text=question.question_text,
                options=option_map[str(question.id)],
                verse_reference=question.verse_reference,
                verse_excerpt=question.verse_excerpt,
                image_asset_key=question.image_asset_key,
                image_alt_text=question.image_alt_text,
                difficulty_tier=question.difficulty_tier,
            )
            for index, question in enumerate(questions)
        ],
    )


def _load_attempt(db: Session, attempt_id: str, user: User) -> LevelAttempt:
    try:
        parsed = uuid.UUID(attempt_id)
    except ValueError as exc:
        raise not_found("attempt_not_found", "That level attempt wasn't found.") from exc
    attempt = db.get(LevelAttempt, parsed)
    if attempt is None or attempt.user_id != user.id:
        raise not_found("attempt_not_found", "That level attempt wasn't found.")
    return attempt


@router.post("/attempts/{attempt_id}/answers", response_model=SubmitAnswerResponse)
def submit_answer(
    attempt_id: str,
    payload: SubmitAnswerRequest,
    user: ConsentedUser,
    db: DbSession,
    context: Context,
) -> SubmitAnswerResponse:
    """Per-answer validation (§21 step 2). The client sends an index, never a score."""
    attempt = _load_attempt(db, attempt_id, user)
    try:
        outcome = gameplay.submit_answer(
            db,
            attempt,
            user,
            question_index=payload.question_index,
            selected_option_index=payload.selected_option_index,
            client_time_taken_ms=payload.client_time_taken_ms,
        )
    except gameplay.GameplayError as exc:
        raise _gameplay_error(exc) from exc

    variant_type = None
    answers = gameplay.recorded_answers(attempt)
    if answers:
        variant_type = answers[-1].get("variant_type")

    if outcome.accepted:
        analytics.track(
            db,
            "question_answered",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "level_id": attempt.level_id,
                "question_index": payload.question_index,
                "question_type": variant_type,
                "is_correct": outcome.correct,
                "time_taken_ms": payload.client_time_taken_ms,
                "timer_remaining_ms": outcome.timer_remaining_ms,
                "attempt_number": attempt.attempt_number,
            },
        )

    if outcome.rejection_reason is not None:
        analytics.track(
            db,
            "leaderboard_attempt_rejected",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "attempt_id": str(attempt.id),
                "rejection_reason": str(outcome.rejection_reason),
                "level_id": attempt.level_id,
            },
        )

    next_level_locked: bool | None = None
    next_level_number: int | None = None
    ad_eligible = False

    if outcome.attempt_status == AttemptStatus.FAILED:
        elapsed = sum(int(item.get("time_taken_ms", 0)) for item in answers)
        analytics.track(
            db,
            "level_failed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "level_id": attempt.level_id,
                "fail_reason": "wrong_answer",
                "question_index_at_fail": payload.question_index,
                "attempt_number": attempt.attempt_number,
                "time_elapsed_ms": elapsed,
            },
        )

    elif outcome.attempt_status == AttemptStatus.COMPLETED:
        has_unlock = accounts.has_unlock(db, user.id)
        next_level_number = min(attempt.level_id + 1, settings.total_levels)
        next_level_locked = next_level_number > settings.free_tier_max_level and not has_unlock

        completion_time_ms = sum(int(item.get("time_taken_ms", 0)) for item in answers)
        analytics.track(
            db,
            "level_completed",
            user=user,
            session_id=context.session_id,
            platform=_platform(context),
            properties={
                "level_id": attempt.level_id,
                "attempts_taken": attempt.attempt_number,
                "completion_time_ms": completion_time_ms,
                "timer_remaining_ms": outcome.timer_remaining_ms,
                "first_try_pass": attempt.attempt_number == 1,
                "next_level_locked": next_level_locked,
            },
        )
        if outcome.leaderboard_entry_id is not None:
            analytics.track(
                db,
                "leaderboard_submitted",
                user=user,
                session_id=context.session_id,
                platform=_platform(context),
                properties={
                    "level_id": attempt.level_id,
                    "score": outcome.score,
                    "attempt_id": str(attempt.id),
                    "is_deferred_sync": False,
                    "user_rank_after": outcome.user_rank,
                },
            )
        # Session counters live on the client; the server reports whether this
        # completion is even a candidate so an under-13 client can never be told yes.
        ad_eligible = ads.ads_allowed_for_user(user) and (
            attempt.level_id >= settings.ad_min_level
        )

    return SubmitAnswerResponse(
        accepted=outcome.accepted,
        correct=outcome.correct,
        attempt_status=outcome.attempt_status,
        expected_next_index=outcome.expected_next_index,
        rejection_reason=outcome.rejection_reason,
        timer_remaining_ms=outcome.timer_remaining_ms,
        score=outcome.score,
        user_rank=outcome.user_rank,
        next_level_locked=next_level_locked,
        next_level_number=next_level_number,
        ad_eligible=ad_eligible,
    )


@router.post("/attempts/{attempt_id}/timer-expired", response_model=AttemptStateResponse)
def report_timer_expired(
    attempt_id: str,
    payload: TimerExpiredRequest,
    user: ConsentedUser,
    db: DbSession,
    context: Context,
) -> AttemptStateResponse:
    """M-16 timer expiry — treated as a fail, no leaderboard entry."""
    attempt = _load_attempt(db, attempt_id, user)
    gameplay.timer_expired(db, attempt, user)

    analytics.track(
        db,
        "timer_expired",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "level_id": attempt.level_id,
            "question_index": payload.question_index,
            "attempt_number": attempt.attempt_number,
        },
    )
    analytics.track(
        db,
        "level_failed",
        user=user,
        session_id=context.session_id,
        platform=_platform(context),
        properties={
            "level_id": attempt.level_id,
            "fail_reason": "timer_expired",
            "question_index_at_fail": payload.question_index,
            "attempt_number": attempt.attempt_number,
            "time_elapsed_ms": sum(
                int(item.get("time_taken_ms", 0))
                for item in gameplay.recorded_answers(attempt)
            ),
        },
    )

    return AttemptStateResponse(
        attempt_id=str(attempt.id),
        status=attempt.status,
        expected_next_index=attempt.expected_next_index,
        score=attempt.computed_score,
        level_number=attempt.level_id,
    )


@router.post("/attempts/{attempt_id}/abandon", response_model=AttemptStateResponse)
def abandon_attempt(
    attempt_id: str, user: ConsentedUser, db: DbSession
) -> AttemptStateResponse:
    """User backed out of a level mid-attempt."""
    attempt = _load_attempt(db, attempt_id, user)
    gameplay.abandon_attempt(db, attempt)
    return AttemptStateResponse(
        attempt_id=str(attempt.id),
        status=attempt.status,
        expected_next_index=attempt.expected_next_index,
        score=attempt.computed_score,
        level_number=attempt.level_id,
    )


@router.get("/attempts/{attempt_id}", response_model=AttemptStateResponse)
def attempt_state(
    attempt_id: str, user: ConsentedUser, db: DbSession
) -> AttemptStateResponse:
    """Lets the client resync after a network drop mid-level (design-spec §15)."""
    attempt = _load_attempt(db, attempt_id, user)
    return AttemptStateResponse(
        attempt_id=str(attempt.id),
        status=attempt.status,
        expected_next_index=attempt.expected_next_index,
        score=attempt.computed_score,
        level_number=attempt.level_id,
    )
