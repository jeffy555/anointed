"""Adaptive difficulty — analytics-spec §13."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import select

from app.models.content import Level, Question
from app.models.enums import AgeGroup, AccountStatus, AuthProvider, DifficultyTier, ReviewStatus, VariantType
from app.models.gameplay import UserPerformanceSummary
from app.models.user import User
from app.services import adaptive_difficulty
from tests.helpers import headers, onboarded_adult, play_level


@pytest.fixture()
def token(client, seeded) -> str:
    return onboarded_adult(client)


@pytest.fixture()
def adult_user(db, seeded) -> User:
    user = User(
        name="Adaptive Tester",
        age=30,
        age_group=AgeGroup.ADULT,
        is_under_13=False,
        account_status=AccountStatus.CONSENTED,
        primary_auth_provider=AuthProvider.PHONE,
    )
    db.add(user)
    db.flush()
    return user


def _summary(
    db,
    user_id: uuid.UUID,
    level_id: int,
    *,
    attempts: int,
    passes: int,
    first_try_passes: int,
    answers: int,
    answer_time_ms: int,
    timer_utilization: float,
    age_group: str = "adult",
) -> UserPerformanceSummary:
    row = UserPerformanceSummary(
        user_id=user_id,
        level_id=level_id,
        age_group=age_group,
        attempts_total=attempts,
        pass_count=passes,
        first_try_passes=first_try_passes,
        answers_total=answers,
        total_answer_time_ms=answer_time_ms,
        total_timer_utilization=timer_utilization * answers if answers else 0.0,
    )
    db.add(row)
    db.flush()
    return row


def test_first_attempt_uses_base_timer(adult_user, db):
    level = db.get(Level, 1)
    summary = adaptive_difficulty.load_performance_summary(db, adult_user.id, 1)
    assert summary is None

    adjustments = adaptive_difficulty.compute_adjustments(adult_user, level, summary)
    assert adjustments.timer_seconds == level.timer_seconds
    assert adjustments.profile == adaptive_difficulty.AdaptiveProfileLabel.FIRST_ATTEMPT


def test_struggling_player_gets_more_time(adult_user, db):
    level = db.get(Level, 1)
    summary = _summary(
        db,
        adult_user.id,
        1,
        attempts=3,
        passes=0,
        first_try_passes=0,
        answers=20,
        answer_time_ms=900_000,
        timer_utilization=0.05,
    )

    adjustments = adaptive_difficulty.compute_adjustments(adult_user, level, summary)
    assert adjustments.timer_seconds > level.timer_seconds
    assert adjustments.profile == adaptive_difficulty.AdaptiveProfileLabel.STRUGGLING
    assert (
        adjustments.tier_weights[DifficultyTier.EASY]
        > adjustments.tier_weights[DifficultyTier.HARD]
    )


def test_excelling_player_gets_slightly_less_time(adult_user, db):
    level = db.get(Level, 1)
    summary = _summary(
        db,
        adult_user.id,
        1,
        attempts=2,
        passes=2,
        first_try_passes=2,
        answers=20,
        answer_time_ms=100_000,
        timer_utilization=0.7,
    )

    adjustments = adaptive_difficulty.compute_adjustments(adult_user, level, summary)
    assert adjustments.timer_seconds < level.timer_seconds
    assert adjustments.profile == adaptive_difficulty.AdaptiveProfileLabel.EXCELLING


def test_kid_timer_never_drops_below_floor(adult_user, db):
    adult_user.age_group = AgeGroup.KID
    db.flush()

    level = db.get(Level, 1)
    level.timer_seconds = 25
    db.flush()

    summary = _summary(
        db,
        adult_user.id,
        1,
        attempts=3,
        passes=3,
        first_try_passes=3,
        answers=30,
        answer_time_ms=60_000,
        timer_utilization=0.8,
        age_group="kid",
    )
    adjustments = adaptive_difficulty.compute_adjustments(adult_user, level, summary)
    assert adjustments.timer_seconds >= 20


def test_failed_attempt_increases_timer_on_retry(client, token):
    first = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    base_timer = first["timer_seconds"]

    play_level(client, token, 1, correct=False)

    second = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    assert second["timer_seconds"] >= base_timer


def test_weighted_draw_favours_easier_questions_when_struggling(seeded, db):
    import random

    from app.models.content import BibleCharacter
    from app.services.gameplay import draw_questions, live_question_pool

    character = db.execute(select(BibleCharacter).limit(1)).scalar_one()
    for tier in (DifficultyTier.MEDIUM, DifficultyTier.HARD, DifficultyTier.EXPERT):
        for index in range(6):
            db.add(
                Question(
                    question_text=f"Weighted {tier.value} {index}",
                    variant_type=VariantType.TEXT_QA,
                    answer_options=[character.name, "A", "B", "C"],
                    correct_answer=character.name,
                    linked_character_id=character.id,
                    level_id=1,
                    difficulty_tier=tier,
                    review_status=ReviewStatus.APPROVED,
                    active=True,
                )
            )
    db.commit()

    pool = live_question_pool(db, 1)
    easy_count = 0
    weights = adaptive_difficulty.STRUGGLING_TIER_WEIGHTS
    for seed in range(40):
        drawn = draw_questions(pool, 10, rng=random.Random(seed), tier_weights=weights)
        easy_count += sum(1 for q in drawn if q.difficulty_tier == DifficultyTier.EASY)

    uniform_easy = 0
    for seed in range(40):
        drawn = draw_questions(pool, 10, rng=random.Random(seed))
        uniform_easy += sum(1 for q in drawn if q.difficulty_tier == DifficultyTier.EASY)

    assert easy_count > uniform_easy
