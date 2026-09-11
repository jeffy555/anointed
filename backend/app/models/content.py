"""Content entities: BibleCharacter, Level, Question, ContentPublishRecord.

Schema follows design-spec §17B (characters), §17C + §18H (questions),
§17D (levels), and §19 (publish records / content_version).
"""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import Boolean, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, timestamp_column, utcnow
from app.models.enums import DifficultyTier, ReviewStatus, Testament, VariantType
from app.models.types import JsonB, UuidPk, new_uuid


class BibleCharacter(Base):
    __tablename__ = "bible_characters"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    name: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text)
    testament: Mapped[Testament | None] = mapped_column(String(8))
    era_tags: Mapped[list[str]] = mapped_column(JsonB, default=list, nullable=False)

    image_asset_key: Mapped[str | None] = mapped_column(String(255))
    image_alt_text: Mapped[str | None] = mapped_column(String(500))

    review_status: Mapped[ReviewStatus] = mapped_column(
        String(16), default=ReviewStatus.DRAFT, nullable=False, index=True
    )
    created_by: Mapped[str | None] = mapped_column(String(160))
    created_at = timestamp_column(default=utcnow, nullable=False)
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)

    questions: Mapped[list[Question]] = relationship(back_populates="character")

    def __str__(self) -> str:  # admin list/relationship labels
        return self.name


class Level(Base):
    __tablename__ = "levels"

    level_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    timer_seconds: Mapped[int] = mapped_column(Integer, default=60, nullable=False)
    difficulty_tier: Mapped[DifficultyTier] = mapped_column(
        String(16), default=DifficultyTier.EASY, nullable=False
    )
    character_pool: Mapped[list[str]] = mapped_column(JsonB, default=list, nullable=False)
    min_questions_required: Mapped[int] = mapped_column(Integer, default=15, nullable=False)
    is_free_tier: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    variant_mix_targets: Mapped[dict[str, Any]] = mapped_column(
        JsonB, default=lambda: {"text_qa": 0.6, "verse_clue": 0.4}, nullable=False
    )
    title: Mapped[str | None] = mapped_column(String(160))
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)

    questions: Mapped[list[Question]] = relationship(back_populates="level")

    def __str__(self) -> str:
        return f"Level {self.level_number}"


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[uuid.UUID] = mapped_column(UuidPk, primary_key=True, default=new_uuid)
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    variant_type: Mapped[VariantType] = mapped_column(
        String(24), default=VariantType.TEXT_QA, nullable=False, index=True
    )

    answer_options: Mapped[list[str]] = mapped_column(JsonB, default=list, nullable=False)
    correct_answer: Mapped[str] = mapped_column(String(500), nullable=False)

    linked_character_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bible_characters.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    level_id: Mapped[int] = mapped_column(
        ForeignKey("levels.level_number", ondelete="CASCADE"), nullable=False, index=True
    )

    difficulty_tier: Mapped[DifficultyTier] = mapped_column(
        String(16), default=DifficultyTier.EASY, nullable=False
    )

    # verse_clue fields (design-spec §18H schema addition)
    verse_reference: Mapped[str | None] = mapped_column(String(120))
    verse_excerpt: Mapped[str | None] = mapped_column(Text)

    # image_clue fields — schema-ready; not launch-blocking
    image_asset_key: Mapped[str | None] = mapped_column(String(255))
    image_alt_text: Mapped[str | None] = mapped_column(String(500))

    active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    review_status: Mapped[ReviewStatus] = mapped_column(
        String(16), default=ReviewStatus.DRAFT, nullable=False, index=True
    )

    created_by: Mapped[str | None] = mapped_column(String(160))
    created_at = timestamp_column(default=utcnow, nullable=False)
    updated_at = timestamp_column(default=utcnow, onupdate=utcnow, nullable=False)

    character: Mapped[BibleCharacter] = relationship(back_populates="questions")
    level: Mapped[Level] = relationship(back_populates="questions")

    __table_args__ = (
        Index("ix_questions_pool_lookup", "level_id", "active", "review_status"),
    )

    @property
    def is_live(self) -> bool:
        return self.active and self.review_status == ReviewStatus.APPROVED

    def correct_option_index(self) -> int:
        try:
            return list(self.answer_options).index(self.correct_answer)
        except ValueError:
            return -1

    def __str__(self) -> str:
        text = self.question_text or ""
        return text if len(text) <= 60 else f"{text[:57]}..."


class ContentPublishRecord(Base):
    """One row per admin content publish. ``content_version`` is monotonic (§19)."""

    __tablename__ = "content_publish_records"

    content_version: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    published_at = timestamp_column(default=utcnow, nullable=False)
    published_by: Mapped[str | None] = mapped_column(String(160))
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)
    pack_size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    min_app_build: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    change_summary: Mapped[str | None] = mapped_column(String(500))
    pack_json: Mapped[dict[str, Any]] = mapped_column(JsonB, nullable=False)
    validation_report: Mapped[dict[str, Any]] = mapped_column(JsonB, default=dict, nullable=False)

    def __str__(self) -> str:
        return f"content_version {self.content_version}"
