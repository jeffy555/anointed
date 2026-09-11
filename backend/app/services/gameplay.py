"""Server-authoritative gameplay: question draw, answer validation, scoring.

Draw rules are design-spec §18H; validation rules and score formula are §21.
The client is never told which option is correct and never computes the score.
"""

from __future__ import annotations

import logging
import random
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.content import Level, Question
from app.models.enums import (
    AttemptMode,
    AttemptStatus,
    DifficultyTier,
    RejectionReason,
    ReviewStatus,
    VariantType,
)
from app.models.gameplay import LeaderboardEntry, LevelAttempt, UserPerformanceSummary
from app.models.user import LevelCompletion, User, UserProgress
from app.services import adaptive_difficulty

logger = logging.getLogger("anointed.gameplay")

MAX_SINGLE_TYPE_PER_ATTEMPT = 6
MIN_VARIANT_TYPES_PER_ATTEMPT = 2


class GameplayError(Exception):
    """Domain failure with a stable code the router maps to an HTTP response."""

    def __init__(self, code: str, message: str, **extra) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.extra = extra


@dataclass
class AnswerOutcome:
    accepted: bool
    correct: bool
    attempt_status: AttemptStatus
    expected_next_index: int
    rejection_reason: RejectionReason | None = None
    score: int | None = None
    timer_remaining_ms: int = 0
    leaderboard_entry_id: uuid.UUID | None = None
    user_rank: int | None = None


def live_question_pool(db: Session, level_number: int) -> list[Question]:
    """Approved + active questions for a level — the only content gameplay may draw."""
    return list(
        db.execute(
            select(Question).where(
                Question.level_id == level_number,
                Question.active.is_(True),
                Question.review_status == ReviewStatus.APPROVED,
            )
        )
        .scalars()
        .all()
    )


def pool_health(db: Session, level: Level) -> dict:
    pool = live_question_pool(db, level.level_number)
    by_type: dict[str, int] = {}
    for question in pool:
        by_type[str(question.variant_type)] = by_type.get(str(question.variant_type), 0) + 1
    return {
        "level_number": level.level_number,
        "live_count": len(pool),
        "min_required": level.min_questions_required,
        "meets_minimum": len(pool) >= level.min_questions_required,
        "playable": len(pool) >= settings.questions_per_attempt,
        "by_variant_type": by_type,
    }


def draw_questions(
    pool: list[Question],
    count: int,
    rng: random.Random | None = None,
    *,
    tier_weights: dict[DifficultyTier, float] | None = None,
) -> list[Question]:
    """Select ``count`` questions honouring the §18H variety rules.

    Rules applied, in order of precedence: no duplicates; cap any single variant
    type at 6 of 10; at least one non-``text_qa``; at least two variant types
    represented; shuffled so types are not clustered. When the pool cannot satisfy
    a variety rule (for example only ``text_qa`` has been authored so far), the
    draw degrades to best-effort and logs a warning rather than blocking play.
    """
    rng = rng or random.Random()
    if len(pool) < count:
        raise GameplayError(
            "insufficient_questions",
            "Something went wrong loading this level. Please try again.",
            available=len(pool),
            required=count,
        )

    def _weighted_pick(candidates: list[Question]) -> Question:
        if not candidates:
            raise IndexError("empty candidate pool")
        if tier_weights is None:
            index = rng.randrange(len(candidates))
            return candidates.pop(index)
        weights = [
            adaptive_difficulty.question_weight(question, tier_weights) for question in candidates
        ]
        chosen = rng.choices(candidates, weights=weights, k=1)[0]
        candidates.remove(chosen)
        return chosen

    by_type: dict[VariantType, list[Question]] = {}
    for question in pool:
        by_type.setdefault(VariantType(question.variant_type), []).append(question)
    for bucket in by_type.values():
        rng.shuffle(bucket)

    selected: list[Question] = []
    per_type_count: dict[VariantType, int] = {key: 0 for key in by_type}

    # Seed one question from each available non-text_qa type first. This is what
    # satisfies "minimum 1 non-text_qa" and "minimum 2 variant types" whenever the
    # pool actually contains the variety, instead of relying on a random draw to
    # happen to include it.
    seed_order = [key for key in by_type if key != VariantType.TEXT_QA]
    rng.shuffle(seed_order)
    for variant in seed_order:
        if len(selected) >= count:
            break
        if by_type[variant]:
            selected.append(_weighted_pick(by_type[variant]))
            per_type_count[variant] += 1

    remaining = [question for bucket in by_type.values() for question in bucket]
    rng.shuffle(remaining)

    cap = MAX_SINGLE_TYPE_PER_ATTEMPT
    while len(selected) < count and remaining:
        eligible = [
            question
            for question in remaining
            if per_type_count[VariantType(question.variant_type)] < cap
        ]
        if not eligible:
            break
        picked = _weighted_pick(eligible)
        remaining.remove(picked)
        variant = VariantType(picked.variant_type)
        selected.append(picked)
        per_type_count[variant] += 1

    if len(selected) < count:
        # Only reachable when the cap itself blocks a full draw, i.e. a pool with
        # too little variety. Variety is a quality goal; playability wins.
        logger.warning(
            "level pool lacks variant variety; relaxing the per-type cap "
            "(selected=%d required=%d types=%s)",
            len(selected),
            count,
            {str(key): len(value) for key, value in by_type.items()},
        )
        already = {question.id for question in selected}
        for question in pool:
            if len(selected) >= count:
                break
            if question.id not in already:
                selected.append(question)
                already.add(question.id)

    distinct_types = {VariantType(question.variant_type) for question in selected}
    if len(distinct_types) < MIN_VARIANT_TYPES_PER_ATTEMPT:
        logger.warning(
            "level pool produced a single-variant attempt (%s); authoring needs "
            "verse_clue coverage per design-spec §18H",
            [str(item) for item in distinct_types],
        )

    rng.shuffle(selected)
    return selected[:count]


def shuffled_options(question: Question, rng: random.Random) -> list[str]:
    options = list(question.answer_options or [])
    rng.shuffle(options)
    return options


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def max_unlocked_level(db: Session, user: User, *, has_unlock: bool) -> int:
    """Highest level the user may start in ranked mode.

    Progression gate plus the IAP gate: free tier is levels 1-5, and beyond that a
    validated purchase is required (design-spec §20, §21).
    """
    progress = db.get(UserProgress, user.id)
    next_level = (progress.highest_level_completed if progress else 0) + 1
    ceiling = settings.total_levels if has_unlock else settings.free_tier_max_level
    return max(1, min(next_level, ceiling))


def assert_can_start(
    db: Session, user: User, level: Level, *, has_unlock: bool
) -> None:
    if level.level_number > settings.free_tier_max_level and not has_unlock:
        raise GameplayError(
            "level_locked",
            "Unlock levels 6\u2013100 to keep playing.",
            level_id=level.level_number,
        )

    progress = db.get(UserProgress, user.id)
    highest = progress.highest_level_completed if progress else 0
    if level.level_number > highest + 1:
        raise GameplayError(
            "level_not_reached",
            "Finish the earlier levels first.",
            level_id=level.level_number,
            next_playable_level=highest + 1,
        )


def start_attempt(
    db: Session,
    user: User,
    level: Level,
    *,
    mode: AttemptMode = AttemptMode.RANKED,
    install_id: str | None = None,
    rng: random.Random | None = None,
) -> tuple[
    LevelAttempt,
    list[Question],
    dict[str, list[str]],
    adaptive_difficulty.AdaptiveAdjustments,
]:
    """Draw questions and open an attempt.

    Returns the attempt, the drawn questions in sequence order, and the per-question
    shuffled option lists. Option order is persisted on the attempt so the index the
    client sends back can be resolved to the option text the player actually saw.
    """
    rng = rng or random.Random()
    pool = live_question_pool(db, level.level_number)

    adjustments = adaptive_difficulty.AdaptiveAdjustments(
        timer_seconds=level.timer_seconds,
        tier_weights=dict(adaptive_difficulty.DEFAULT_TIER_WEIGHTS),
        profile=adaptive_difficulty.AdaptiveProfileLabel.COMFORTABLE,
        base_timer_seconds=level.timer_seconds,
    )
    if mode == AttemptMode.RANKED:
        summary = adaptive_difficulty.load_performance_summary(db, user.id, level.level_number)
        adjustments = adaptive_difficulty.compute_adjustments(user, level, summary)

    questions = draw_questions(
        pool,
        settings.questions_per_attempt,
        rng=rng,
        tier_weights=adjustments.tier_weights,
    )

    option_map: dict[str, list[str]] = {}
    for question in questions:
        option_map[str(question.id)] = shuffled_options(question, rng)

    # Abandon any attempt this user left open on this level so a player cannot hold
    # several live attempts and cherry-pick the best one.
    for stale in (
        db.execute(
            select(LevelAttempt).where(
                LevelAttempt.user_id == user.id,
                LevelAttempt.level_id == level.level_number,
                LevelAttempt.status == AttemptStatus.IN_PROGRESS,
            )
        )
        .scalars()
        .all()
    ):
        stale.status = AttemptStatus.ABANDONED

    previous_attempts = db.execute(
        select(func.count())
        .select_from(LevelAttempt)
        .where(
            LevelAttempt.user_id == user.id,
            LevelAttempt.level_id == level.level_number,
            LevelAttempt.mode == mode,
        )
    ).scalar_one()

    total_budget_seconds = (
        adjustments.timer_seconds * settings.questions_per_attempt
        + settings.attempt_total_grace_seconds
    )
    attempt = LevelAttempt(
        user_id=user.id,
        level_id=level.level_number,
        mode=mode,
        status=AttemptStatus.IN_PROGRESS,
        question_sequence=[str(question.id) for question in questions],
        expected_next_index=0,
        answers=[],
        attempt_number=int(previous_attempts) + 1,
        timer_seconds=adjustments.timer_seconds,
        install_id=install_id,
        started_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc) + timedelta(seconds=total_budget_seconds),
    )
    # Persisted alongside the answers so option order survives a process restart.
    attempt.answers = [{"__option_order__": option_map}]
    db.add(attempt)
    db.flush()
    return attempt, questions, option_map, adjustments


def _option_order(attempt: LevelAttempt) -> dict[str, list[str]]:
    if attempt.answers and isinstance(attempt.answers[0], dict):
        return attempt.answers[0].get("__option_order__", {}) or {}
    return {}


def recorded_answers(attempt: LevelAttempt) -> list[dict]:
    return [item for item in (attempt.answers or []) if "__option_order__" not in item]


def submit_answer(
    db: Session,
    attempt: LevelAttempt,
    user: User,
    *,
    question_index: int,
    selected_option_index: int,
    client_time_taken_ms: int,
) -> AnswerOutcome:
    """Validate one answer against server truth and advance or fail the attempt."""
    now = datetime.now(timezone.utc)

    if attempt.status != AttemptStatus.IN_PROGRESS:
        raise GameplayError(
            "attempt_not_active",
            "That level attempt has already finished.",
            status=str(attempt.status),
        )

    expires_at = _aware(attempt.expires_at)
    if expires_at and now > expires_at:
        attempt.status = AttemptStatus.EXPIRED
        attempt.rejection_reason = RejectionReason.EXPIRED
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=False,
            correct=False,
            attempt_status=AttemptStatus.EXPIRED,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.EXPIRED,
        )

    if question_index != attempt.expected_next_index:
        attempt.status = AttemptStatus.INVALID
        attempt.rejection_reason = RejectionReason.SEQUENCE_VIOLATION
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=False,
            correct=False,
            attempt_status=AttemptStatus.INVALID,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.SEQUENCE_VIOLATION,
        )

    if client_time_taken_ms < settings.answer_time_floor_ms:
        # Faster than a human can read the question: flag rather than fail outright,
        # so a flagged attempt is excluded from the leaderboard and visible to admin.
        attempt.status = AttemptStatus.SUSPICIOUS
        attempt.suspicious = True
        attempt.rejection_reason = RejectionReason.TIME_FLOOR
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=False,
            correct=False,
            attempt_status=AttemptStatus.SUSPICIOUS,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.TIME_FLOOR,
        )

    ceiling_ms = attempt.timer_seconds * 1000 + settings.answer_time_ceiling_grace_ms
    if client_time_taken_ms > ceiling_ms:
        attempt.status = AttemptStatus.INVALID
        attempt.rejection_reason = RejectionReason.TIME_CEILING
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=False,
            correct=False,
            attempt_status=AttemptStatus.INVALID,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.TIME_CEILING,
        )

    question_id = attempt.question_sequence[question_index]
    question = db.get(Question, uuid.UUID(question_id))
    if question is None:
        raise GameplayError(
            "question_missing", "Something went wrong loading this level. Please try again."
        )

    options = _option_order(attempt).get(question_id) or list(question.answer_options or [])
    selected_text = (
        options[selected_option_index]
        if 0 <= selected_option_index < len(options)
        else None
    )
    is_correct = selected_text is not None and selected_text == question.correct_answer

    timer_remaining_ms = max(attempt.timer_seconds * 1000 - client_time_taken_ms, 0)

    answers = list(attempt.answers or [])
    answers.append(
        {
            "question_id": question_id,
            "question_index": question_index,
            "selected_index": selected_option_index,
            "time_taken_ms": client_time_taken_ms,
            "timer_remaining_ms": timer_remaining_ms,
            "received_at": now.isoformat(),
            "correct": is_correct,
            "variant_type": str(question.variant_type),
        }
    )
    attempt.answers = answers

    if not is_correct:
        # Any wrong answer ends the attempt immediately; no partial credit and the
        # correct answer is never revealed (design-spec §1D, Flow 3).
        attempt.status = AttemptStatus.FAILED
        attempt.completed_at = now
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=True,
            correct=False,
            attempt_status=AttemptStatus.FAILED,
            expected_next_index=question_index,
            timer_remaining_ms=timer_remaining_ms,
        )

    attempt.expected_next_index = question_index + 1

    if attempt.expected_next_index < settings.questions_per_attempt:
        return AnswerOutcome(
            accepted=True,
            correct=True,
            attempt_status=AttemptStatus.IN_PROGRESS,
            expected_next_index=attempt.expected_next_index,
            timer_remaining_ms=timer_remaining_ms,
        )

    return _complete_attempt(db, attempt, user, now=now)


def _complete_attempt(
    db: Session, attempt: LevelAttempt, user: User, *, now: datetime
) -> AnswerOutcome:
    answers = recorded_answers(attempt)
    total_time_ms = sum(int(item.get("time_taken_ms", 0)) for item in answers)
    minimum_total_ms = settings.answer_time_floor_ms * settings.questions_per_attempt

    if total_time_ms < minimum_total_ms:
        attempt.status = AttemptStatus.SUSPICIOUS
        attempt.suspicious = True
        attempt.rejection_reason = RejectionReason.TIME_FLOOR
        attempt.completed_at = now
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=True,
            correct=True,
            attempt_status=AttemptStatus.SUSPICIOUS,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.TIME_FLOOR,
        )

    started_at = _aware(attempt.started_at) or now
    budget_seconds = (
        attempt.timer_seconds * settings.questions_per_attempt
        + settings.attempt_total_grace_seconds
    )
    if (now - started_at).total_seconds() > budget_seconds:
        attempt.status = AttemptStatus.EXPIRED
        attempt.rejection_reason = RejectionReason.EXPIRED
        attempt.completed_at = now
        _update_performance(db, attempt, user, passed=False)
        return AnswerOutcome(
            accepted=True,
            correct=True,
            attempt_status=AttemptStatus.EXPIRED,
            expected_next_index=attempt.expected_next_index,
            rejection_reason=RejectionReason.EXPIRED,
        )

    # Score = sum of timer remaining at each correct answer, in whole seconds (§21).
    score = sum(int(item.get("timer_remaining_ms", 0)) for item in answers) // 1000
    attempt.status = AttemptStatus.COMPLETED
    attempt.completed_at = now
    attempt.computed_score = score

    _record_completion(db, attempt, user, score=score)

    entry_id: uuid.UUID | None = None
    rank: int | None = None
    if attempt.mode == AttemptMode.RANKED and not attempt.suspicious:
        entry = LeaderboardEntry(
            user_id=user.id,
            attempt_id=attempt.id,
            level_id=attempt.level_id,
            score=score,
            display_name=user.leaderboard_display_name,
            is_under_13=user.is_under_13,
        )
        db.add(entry)
        db.flush()
        entry_id = entry.id
        rank = rank_for_score(db, score)

    _update_performance(db, attempt, user, passed=True)

    return AnswerOutcome(
        accepted=True,
        correct=True,
        attempt_status=AttemptStatus.COMPLETED,
        expected_next_index=attempt.expected_next_index,
        score=score,
        timer_remaining_ms=int(answers[-1].get("timer_remaining_ms", 0)) if answers else 0,
        leaderboard_entry_id=entry_id,
        user_rank=rank,
    )


def rank_for_score(db: Session, score: int) -> int:
    """1-based rank on the all-time board: one more than the count of better scores."""
    better = db.execute(
        select(func.count())
        .select_from(LeaderboardEntry)
        .where(LeaderboardEntry.revoked.is_(False), LeaderboardEntry.score > score)
    ).scalar_one()
    return int(better) + 1


def _record_completion(db: Session, attempt: LevelAttempt, user: User, *, score: int) -> None:
    progress = db.get(UserProgress, user.id)
    if progress is None:
        progress = UserProgress(user_id=user.id)
        db.add(progress)
        db.flush()

    completion = db.get(LevelCompletion, (user.id, attempt.level_id))
    now = datetime.now(timezone.utc)
    if completion is None:
        completion = LevelCompletion(
            user_id=user.id,
            level_number=attempt.level_id,
            best_score=score,
            attempts_taken=attempt.attempt_number,
            first_completed_at=now,
            last_completed_at=now,
        )
        db.add(completion)
        progress.levels_completed_count += 1
        progress.total_score += score
    else:
        if score > completion.best_score:
            progress.total_score += score - completion.best_score
            completion.best_score = score
        completion.last_completed_at = now

    progress.highest_level_completed = max(progress.highest_level_completed, attempt.level_id)
    progress.last_attempt_at = now
    db.flush()


def _update_performance(
    db: Session, attempt: LevelAttempt, user: User, *, passed: bool
) -> None:
    """Roll the per-user/per-level aggregate that feeds adaptive difficulty.

    Shape from analytics-spec §13. Deliberately additive counters rather than
    recomputed averages so this stays a cheap upsert.
    """
    summary = db.get(UserPerformanceSummary, (user.id, attempt.level_id))
    if summary is None:
        summary = UserPerformanceSummary(
            user_id=user.id,
            level_id=attempt.level_id,
            age_group=str(user.age_group) if user.age_group else None,
        )
        db.add(summary)
        db.flush()

    answers = recorded_answers(attempt)
    summary.attempts_total += 1
    summary.answers_total += len(answers)
    summary.total_answer_time_ms += sum(int(item.get("time_taken_ms", 0)) for item in answers)
    timer_ms = max(attempt.timer_seconds * 1000, 1)
    summary.total_timer_utilization += sum(
        int(item.get("timer_remaining_ms", 0)) / timer_ms for item in answers
    )
    if passed:
        summary.pass_count += 1
        if attempt.attempt_number == 1:
            summary.first_try_passes += 1
    db.flush()


def abandon_attempt(db: Session, attempt: LevelAttempt) -> None:
    if attempt.status == AttemptStatus.IN_PROGRESS:
        attempt.status = AttemptStatus.ABANDONED
        attempt.completed_at = datetime.now(timezone.utc)


def timer_expired(db: Session, attempt: LevelAttempt, user: User) -> None:
    """M-16: client reports the countdown hit zero; treated as a fail (§1D)."""
    if attempt.status == AttemptStatus.IN_PROGRESS:
        attempt.status = AttemptStatus.FAILED
        attempt.rejection_reason = None
        attempt.completed_at = datetime.now(timezone.utc)
        _update_performance(db, attempt, user, passed=False)
