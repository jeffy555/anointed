"""Adaptive difficulty — consumes ``UserPerformanceSummary`` (analytics-spec §13).

Adjusts per-attempt timer pressure and question-tier draw weights from rolling
performance history, within age-appropriate bounds.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.content import Level, Question
from app.models.enums import AgeGroup, DifficultyTier
from app.models.gameplay import UserPerformanceSummary
from app.models.user import User


class AdaptiveProfileLabel(StrEnum):
    FIRST_ATTEMPT = "first_attempt"
    COMFORTABLE = "comfortable"
    STRUGGLING = "struggling"
    EXCELLING = "excelling"
    ELDER_SUPPORT = "elder_support"


DEFAULT_TIER_WEIGHTS: dict[DifficultyTier, float] = {
    DifficultyTier.EASY: 1.0,
    DifficultyTier.MEDIUM: 1.0,
    DifficultyTier.HARD: 1.0,
    DifficultyTier.EXPERT: 1.0,
}

STRUGGLING_TIER_WEIGHTS: dict[DifficultyTier, float] = {
    DifficultyTier.EASY: 3.0,
    DifficultyTier.MEDIUM: 2.0,
    DifficultyTier.HARD: 0.5,
    DifficultyTier.EXPERT: 0.25,
}

EXCELLING_TIER_WEIGHTS: dict[DifficultyTier, float] = {
    DifficultyTier.EASY: 0.5,
    DifficultyTier.MEDIUM: 1.5,
    DifficultyTier.HARD: 2.0,
    DifficultyTier.EXPERT: 2.5,
}


@dataclass(frozen=True)
class AdaptiveAdjustments:
    """Timer and question draw inputs for one attempt start."""

    timer_seconds: int
    tier_weights: dict[DifficultyTier, float]
    profile: AdaptiveProfileLabel
    base_timer_seconds: int


def _age_group(user: User) -> AgeGroup:
    if user.age_group:
        try:
            return AgeGroup(str(user.age_group))
        except ValueError:
            pass
    return AgeGroup.ADULT


def _min_timer_for(age_group: AgeGroup) -> int:
    if age_group == AgeGroup.KID:
        return settings.adaptive_min_timer_kid
    if age_group == AgeGroup.ELDER:
        return settings.adaptive_min_timer_elder
    return settings.adaptive_min_timer_default


def load_performance_summary(
    db: Session, user_id, level_number: int
) -> UserPerformanceSummary | None:
    """Prefer this level's history; fall back to the prior level when new."""
    summary = db.get(UserPerformanceSummary, (user_id, level_number))
    if summary is not None and summary.attempts_total > 0:
        return summary
    if level_number > 1:
        prior = db.get(UserPerformanceSummary, (user_id, level_number - 1))
        if prior is not None and prior.attempts_total > 0:
            return prior
    return None


def compute_adjustments(
    user: User,
    level: Level,
    summary: UserPerformanceSummary | None,
) -> AdaptiveAdjustments:
    """Derive timer and tier weights from performance history."""
    if not settings.adaptive_enabled:
        return AdaptiveAdjustments(
            timer_seconds=level.timer_seconds,
            tier_weights=dict(DEFAULT_TIER_WEIGHTS),
            profile=AdaptiveProfileLabel.COMFORTABLE,
            base_timer_seconds=level.timer_seconds,
        )

    base = level.timer_seconds
    age_group = _age_group(user)
    min_timer = _min_timer_for(age_group)
    max_timer = min(settings.adaptive_max_timer, base + settings.adaptive_timer_bonus_cap)

    if summary is None or summary.attempts_total <= 0:
        return AdaptiveAdjustments(
            timer_seconds=base,
            tier_weights=dict(DEFAULT_TIER_WEIGHTS),
            profile=AdaptiveProfileLabel.FIRST_ATTEMPT,
            base_timer_seconds=base,
        )

    attempts = summary.attempts_total
    passes = summary.pass_count
    pass_rate = passes / attempts if attempts else 0.0
    utilization = summary.avg_timer_utilization
    first_try_rate = summary.first_try_pass_rate

    # Elder: extra time on early failures (analytics-spec §13).
    if (
        age_group == AgeGroup.ELDER
        and passes == 0
        and 1 <= attempts <= settings.adaptive_elder_failed_attempts
    ):
        timer = min(max_timer, base + settings.adaptive_elder_failed_bonus_seconds)
        return AdaptiveAdjustments(
            timer_seconds=max(min_timer, timer),
            tier_weights=dict(STRUGGLING_TIER_WEIGHTS),
            profile=AdaptiveProfileLabel.ELDER_SUPPORT,
            base_timer_seconds=base,
        )

    struggling = (
        (passes == 0 and attempts >= 2)
        or pass_rate < settings.adaptive_struggling_pass_rate
        or utilization < settings.adaptive_struggling_timer_utilization
    )
    excelling = (
        (passes > 0 and first_try_rate >= settings.adaptive_excelling_first_try_rate)
        or (
            passes > 0
            and utilization >= settings.adaptive_excelling_timer_utilization
            and pass_rate >= settings.adaptive_excelling_pass_rate
        )
    )

    if struggling and not excelling:
        bonus = min(
            settings.adaptive_timer_bonus_cap,
            settings.adaptive_timer_step_seconds * max(0, attempts - passes),
        )
        timer = min(max_timer, base + bonus)
        return AdaptiveAdjustments(
            timer_seconds=max(min_timer, timer),
            tier_weights=dict(STRUGGLING_TIER_WEIGHTS),
            profile=AdaptiveProfileLabel.STRUGGLING,
            base_timer_seconds=base,
        )

    if excelling and not struggling:
        penalty = settings.adaptive_timer_step_seconds // 2
        timer = max(min_timer, base - penalty)
        return AdaptiveAdjustments(
            timer_seconds=timer,
            tier_weights=dict(EXCELLING_TIER_WEIGHTS),
            profile=AdaptiveProfileLabel.EXCELLING,
            base_timer_seconds=base,
        )

    return AdaptiveAdjustments(
        timer_seconds=max(min_timer, min(max_timer, base)),
        tier_weights=dict(DEFAULT_TIER_WEIGHTS),
        profile=AdaptiveProfileLabel.COMFORTABLE,
        base_timer_seconds=base,
    )


def question_weight(question: Question, tier_weights: dict[DifficultyTier, float]) -> float:
    tier = DifficultyTier(question.difficulty_tier)
    return max(0.01, tier_weights.get(tier, 1.0))
