"""Practice Content Pack build, validation, and publish (design-spec §19).

``content_version`` is monotonic and only advances on an explicit admin publish;
draft and in-review edits are invisible to clients until then.
"""

from __future__ import annotations

import gzip
import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.content import BibleCharacter, ContentPublishRecord, Level, Question
from app.models.enums import LAUNCH_VARIANT_TYPES, ReviewStatus, VariantType


@dataclass
class ValidationReport:
    """Pool-health result for a publish attempt (design-spec §23 publish step 1-2)."""

    ok: bool
    threshold: int
    levels_below_minimum: list[dict] = field(default_factory=list)
    levels_missing_launch_variety: list[int] = field(default_factory=list)
    total_live_questions: int = 0
    total_levels: int = 0

    def as_dict(self) -> dict:
        return {
            "ok": self.ok,
            "threshold": self.threshold,
            "levels_below_minimum": self.levels_below_minimum,
            "levels_missing_launch_variety": self.levels_missing_launch_variety,
            "total_live_questions": self.total_live_questions,
            "total_levels": self.total_levels,
        }

    def summary(self) -> str:
        if self.ok:
            return (
                f"{self.total_live_questions} live questions across {self.total_levels} levels; "
                f"all levels meet the {self.threshold}-question minimum."
            )
        parts = []
        if self.levels_below_minimum:
            shortfalls = ", ".join(
                f"L{item['level_number']} ({item['live_count']}/{item['min_required']})"
                for item in self.levels_below_minimum[:10]
            )
            more = (
                f" and {len(self.levels_below_minimum) - 10} more"
                if len(self.levels_below_minimum) > 10
                else ""
            )
            parts.append(f"{len(self.levels_below_minimum)} level(s) below minimum: {shortfalls}{more}")
        if self.levels_missing_launch_variety:
            preview = ", ".join(
                f"L{number}" for number in self.levels_missing_launch_variety[:10]
            )
            parts.append(
                f"{len(self.levels_missing_launch_variety)} level(s) lack both launch "
                f"variant types (text_qa + verse_clue): {preview}"
            )
        return "; ".join(parts)


def live_questions(db: Session) -> list[Question]:
    return list(
        db.execute(
            select(Question).where(
                Question.active.is_(True), Question.review_status == ReviewStatus.APPROVED
            )
        )
        .scalars()
        .all()
    )


def validate_for_publish(db: Session, *, threshold: int | None = None) -> ValidationReport:
    """Check every level's approved+active pool before allowing a publish.

    ``threshold`` defaults to each level's own ``min_questions_required``, falling
    back to the beta minimum. Passing an explicit value lets an operator publish
    against the beta bar early in content authoring and the launch bar later.
    """
    levels = list(db.execute(select(Level).order_by(Level.level_number)).scalars().all())
    questions = live_questions(db)

    by_level: dict[int, list[Question]] = {}
    for question in questions:
        by_level.setdefault(question.level_id, []).append(question)

    report = ValidationReport(
        ok=True,
        threshold=threshold or settings.beta_min_questions_per_level,
        total_live_questions=len(questions),
        total_levels=len(levels),
    )

    for level in levels:
        pool = by_level.get(level.level_number, [])
        minimum = threshold if threshold is not None else level.min_questions_required
        if len(pool) < minimum:
            report.levels_below_minimum.append(
                {
                    "level_number": level.level_number,
                    "live_count": len(pool),
                    "min_required": minimum,
                }
            )
        present = {VariantType(question.variant_type) for question in pool}
        if not all(variant in present for variant in LAUNCH_VARIANT_TYPES):
            report.levels_missing_launch_variety.append(level.level_number)

    report.ok = not report.levels_below_minimum
    return report


def build_pack(db: Session, *, content_version: int) -> dict:
    """Serialise everything practice mode needs to run fully offline (§19).

    Offline practice is limited to the free tier (levels 1–5) so the on-device
    pack stays small and matches what players can access without IAP.
    """
    max_level = settings.free_tier_max_level
    levels = list(
        db.execute(
            select(Level)
            .where(Level.level_number <= max_level)
            .order_by(Level.level_number)
        )
        .scalars()
        .all()
    )
    questions = [
        question
        for question in live_questions(db)
        if question.level_id <= max_level
    ]
    character_ids = {question.linked_character_id for question in questions}
    characters = (
        list(
            db.execute(
                select(BibleCharacter).where(BibleCharacter.id.in_(character_ids))
            )
            .scalars()
            .all()
        )
        if character_ids
        else []
    )

    return {
        "content_version": content_version,
        "published_at": datetime.now(timezone.utc).isoformat(),
        "min_app_build": settings.minimum_app_build,
        "levels": [
            {
                "level_number": level.level_number,
                "title": level.title,
                "timer_seconds": level.timer_seconds,
                "difficulty_tier": str(level.difficulty_tier),
                "is_free_tier": level.is_free_tier,
            }
            for level in levels
        ],
        "characters": [
            {
                "id": str(character.id),
                "name": character.name,
                "testament": str(character.testament) if character.testament else None,
                "image_asset_key": character.image_asset_key,
                "image_alt_text": character.image_alt_text,
            }
            for character in characters
        ],
        "questions": [
            {
                "id": str(question.id),
                "level_number": question.level_id,
                "variant_type": str(question.variant_type),
                "question_text": question.question_text,
                "answer_options": list(question.answer_options or []),
                # Practice mode is offline and never touches the leaderboard, so the
                # correct answer must ship inside the pack. This is deliberate: the
                # value of a leak is nil because practice results are not ranked, and
                # ranked play never reads the pack.
                "correct_answer": question.correct_answer,
                "linked_character_id": str(question.linked_character_id),
                "difficulty_tier": str(question.difficulty_tier),
                "verse_reference": question.verse_reference,
                "verse_excerpt": question.verse_excerpt,
                "image_asset_key": question.image_asset_key,
                "image_alt_text": question.image_alt_text,
            }
            for question in questions
        ],
        # Image blobs are not embedded in v1; image_clue assets are post-launch (§18H).
        "assets": [],
    }


def canonical_json(pack: dict) -> bytes:
    """Stable byte representation so the checksum is reproducible."""
    return json.dumps(pack, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def checksum_for(pack: dict) -> str:
    return hashlib.sha256(canonical_json(pack)).hexdigest()


def gzip_pack(pack: dict) -> bytes:
    return gzip.compress(canonical_json(pack), compresslevel=6)


def current_publish(db: Session) -> ContentPublishRecord | None:
    return db.execute(
        select(ContentPublishRecord).order_by(ContentPublishRecord.content_version.desc())
    ).scalars().first()


def current_version(db: Session) -> int:
    record = current_publish(db)
    return record.content_version if record else 0


def publish(
    db: Session,
    *,
    published_by: str | None,
    change_summary: str | None = None,
    threshold: int | None = None,
    force: bool = False,
) -> tuple[ContentPublishRecord, ValidationReport]:
    """Validate, build, and record a new content version.

    ``force`` records the failing validation report alongside the publish rather
    than discarding it, so an operator who deliberately publishes a partial pool
    leaves an auditable reason behind.
    """
    report = validate_for_publish(db, threshold=threshold)
    if not report.ok and not force:
        return None, report  # type: ignore[return-value]

    next_version = current_version(db) + 1
    pack = build_pack(db, content_version=next_version)
    compressed = gzip_pack(pack)

    record = ContentPublishRecord(
        content_version=next_version,
        published_by=published_by,
        checksum=checksum_for(pack),
        pack_size_bytes=len(compressed),
        min_app_build=settings.minimum_app_build,
        change_summary=change_summary,
        pack_json=pack,
        validation_report=report.as_dict(),
    )
    db.add(record)
    db.flush()
    return record, report
