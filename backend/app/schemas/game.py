"""Gameplay and level-map schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.models.enums import AttemptStatus, DifficultyTier, RejectionReason, VariantType
from app.schemas.common import ApiModel


class LevelSummary(ApiModel):
    """One node on the M-11 level map."""

    level_number: int
    title: str | None
    difficulty_tier: DifficultyTier
    timer_seconds: int
    is_free_tier: bool
    locked: bool
    completed: bool
    best_score: int | None
    is_current: bool
    playable: bool
    available_variant_types: list[VariantType]


class LevelMapResponse(ApiModel):
    levels: list[LevelSummary]
    highest_level_completed: int
    current_level: int
    has_unlock: bool
    free_tier_max_level: int
    total_levels: int


class LevelDetailResponse(ApiModel):
    """M-12 pre-level card."""

    level_number: int
    title: str | None
    difficulty_tier: DifficultyTier
    timer_seconds: int
    questions_per_attempt: int
    is_free_tier: bool
    locked: bool
    completed: bool
    best_score: int | None
    available_variant_types: list[VariantType]
    pool_size: int
    playable: bool


class AttemptQuestion(ApiModel):
    """A question as the client sees it — no correct answer, options pre-shuffled."""

    question_index: int
    question_id: str
    variant_type: VariantType
    question_text: str
    options: list[str]
    verse_reference: str | None = None
    verse_excerpt: str | None = None
    image_asset_key: str | None = None
    image_alt_text: str | None = None
    difficulty_tier: DifficultyTier


class StartAttemptRequest(ApiModel):
    mode: str = Field(default="ranked", pattern="^(ranked|practice)$")


class StartAttemptResponse(ApiModel):
    attempt_id: str
    level_number: int
    timer_seconds: int
    attempt_number: int
    expires_at: datetime
    questions: list[AttemptQuestion]


class SubmitAnswerRequest(ApiModel):
    question_index: int = Field(ge=0)
    selected_option_index: int = Field(ge=0, le=9)
    client_time_taken_ms: int = Field(ge=0, le=600_000)


class SubmitAnswerResponse(ApiModel):
    accepted: bool
    correct: bool
    attempt_status: AttemptStatus
    expected_next_index: int
    rejection_reason: RejectionReason | None = None
    timer_remaining_ms: int = 0
    # Present only on the 10th correct answer; always server-computed.
    score: int | None = None
    user_rank: int | None = None
    next_level_locked: bool | None = None
    next_level_number: int | None = None
    ad_eligible: bool = False


class TimerExpiredRequest(ApiModel):
    question_index: int = Field(ge=0)


class AttemptStateResponse(ApiModel):
    attempt_id: str
    status: AttemptStatus
    expected_next_index: int
    score: int | None
    level_number: int
