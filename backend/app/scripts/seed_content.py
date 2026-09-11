"""Dev/QA content seed — build order A.3.

Creates the 100 level rows, imports the curated character set, and generates an
approved+active question pool large enough for gameplay, the practice pack, and
leaderboard testing. Idempotent: re-running updates rather than duplicating.

    python -m app.scripts.seed_content --questions-per-level 15 --publish

This is explicitly *not* the launch content set. Real authoring happens through the
admin dashboard (Track A); this exists so engineering is not blocked on it.
"""

from __future__ import annotations

import argparse
import random
import sys

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import Base, SessionLocal, engine
from app.models.content import BibleCharacter, Level, Question
from app.models.enums import DifficultyTier, ReviewStatus, Testament, VariantType
from app.scripts.seed_data import CHARACTERS
from app.services import character_assets, content_pack

SEED_AUTHOR = "seed-script"


def tier_for_level(level_number: int) -> DifficultyTier:
    """Difficulty curve from design-spec §17E."""
    if level_number <= 5:
        return DifficultyTier.EASY
    if level_number <= 50:
        return DifficultyTier.EASY if level_number % 2 else DifficultyTier.MEDIUM
    if level_number <= 80:
        return DifficultyTier.MEDIUM if level_number % 2 else DifficultyTier.HARD
    return DifficultyTier.HARD if level_number % 2 else DifficultyTier.EXPERT


TIMER_BY_TIER = {
    DifficultyTier.EASY: 60,
    DifficultyTier.MEDIUM: 45,
    DifficultyTier.HARD: 30,
    DifficultyTier.EXPERT: 20,
}


def ensure_levels(db: Session) -> list[Level]:
    levels: list[Level] = []
    for number in range(1, settings.total_levels + 1):
        tier = tier_for_level(number)
        level = db.get(Level, number)
        if level is None:
            level = Level(level_number=number)
            db.add(level)
        level.title = f"Level {number}"
        level.difficulty_tier = tier
        level.timer_seconds = TIMER_BY_TIER[tier]
        level.is_free_tier = number <= settings.free_tier_max_level
        level.min_questions_required = settings.beta_min_questions_per_level
        level.variant_mix_targets = {"text_qa": 0.6, "verse_clue": 0.4}
        levels.append(level)
    db.flush()
    return levels


def ensure_characters(db: Session) -> dict[str, BibleCharacter]:
    existing = {
        character.name: character
        for character in db.execute(select(BibleCharacter)).scalars().all()
    }
    result: dict[str, BibleCharacter] = {}
    for seed in CHARACTERS:
        character = existing.get(seed["name"])
        if character is None:
            character = BibleCharacter(name=seed["name"], created_by=SEED_AUTHOR)
            db.add(character)
        character.description = seed["description"]
        character.testament = Testament(seed["testament"])
        character.era_tags = list(seed["era_tags"])
        character.review_status = ReviewStatus.APPROVED
        character.image_asset_key = character_assets.asset_key_for_character(seed["name"])
        character.image_alt_text = seed["description"]
        result[seed["name"]] = character
    db.flush()
    return result


def _distractors(
    correct_name: str, testament: str, rng: random.Random, pool: list[str]
) -> list[str]:
    """Three wrong options from the same testament, so the choice is a real test."""
    same = [name for name in pool if name != correct_name]
    rng.shuffle(same)
    picked = same[:3]
    if len(picked) < 3:  # tiny dataset guard
        extras = [
            name for name in (item["name"] for item in CHARACTERS) if name != correct_name
        ]
        rng.shuffle(extras)
        for name in extras:
            if len(picked) >= 3:
                break
            if name not in picked:
                picked.append(name)
    return picked[:3]


def generate_questions(
    db: Session,
    characters: dict[str, BibleCharacter],
    levels: list[Level],
    *,
    per_level: int,
    seed: int = 20260901,
) -> int:
    """Compose a question pool per level from the curated facts and verses.

    Each level draws from a rotating slice of the character set so different levels
    ask about different people, and every level gets both launch variant types.
    """
    rng = random.Random(seed)

    by_testament: dict[str, list[str]] = {"old": [], "new": []}
    for item in CHARACTERS:
        by_testament[item["testament"]].append(item["name"])

    # A stable key per generated question keeps the seed idempotent.
    existing_keys = {
        (question.level_id, question.question_text)
        for question in db.execute(select(Question)).scalars().all()
    }

    created = 0
    seed_by_name = {item["name"]: item for item in CHARACTERS}
    names = [item["name"] for item in CHARACTERS]

    for level in levels:
        # Rotate the starting offset so level pools differ from each other.
        offset = (level.level_number * 7) % len(names)
        rotated = names[offset:] + names[:offset]

        candidates: list[
            tuple[str, str, VariantType, str | None, str | None, str | None, str | None]
        ] = []
        for name in rotated:
            data = seed_by_name[name]
            for fact in data["facts"]:
                candidates.append((name, fact, VariantType.TEXT_QA, None, None, None, None))
            for verse in data["verses"]:
                candidates.append(
                    (
                        name,
                        "Which Bible character is this verse about?",
                        VariantType.VERSE_CLUE,
                        verse["reference"],
                        verse["excerpt"],
                        None,
                        None,
                    )
                )
            candidates.append(
                (
                    name,
                    "Who is this Bible character?",
                    VariantType.IMAGE_CLUE,
                    None,
                    None,
                    character_assets.asset_key_for_character(name),
                    data["description"],
                )
            )

        text_items = [item for item in candidates if item[2] == VariantType.TEXT_QA]
        verse_items = [item for item in candidates if item[2] == VariantType.VERSE_CLUE]
        image_items = [item for item in candidates if item[2] == VariantType.IMAGE_CLUE]

        # §18H mix: text_qa majority, verse_clue + image_clue for variety.
        image_target = max(1, round(per_level * 0.2))
        verse_target = max(2, round(per_level * 0.35))
        text_target = max(1, per_level - verse_target - image_target)
        chosen = (
            text_items[:text_target]
            + verse_items[:verse_target]
            + image_items[:image_target]
        )
        if len(chosen) < per_level:
            chosen += [item for item in candidates if item not in chosen][
                : per_level - len(chosen)
            ]

        for name, prompt, variant, reference, excerpt, image_key, image_alt in chosen:
            character = characters[name]
            testament = seed_by_name[name]["testament"]

            # verse_clue prompts are identical across characters, so the stored text
            # includes the reference to keep the idempotency key unique per level.
            stored_prompt = prompt if variant == VariantType.TEXT_QA else prompt
            if variant == VariantType.TEXT_QA:
                dedupe_key = (level.level_number, stored_prompt)
            elif variant == VariantType.VERSE_CLUE:
                dedupe_key = (level.level_number, f"{stored_prompt}|{reference}")
            else:
                dedupe_key = (level.level_number, f"{stored_prompt}|{name}|image")
            if dedupe_key in existing_keys:
                continue
            existing_keys.add(dedupe_key)

            options = [name] + _distractors(
                name, testament, rng, by_testament[testament]
            )
            rng.shuffle(options)

            db.add(
                Question(
                    question_text=stored_prompt,
                    variant_type=variant,
                    answer_options=options,
                    correct_answer=name,
                    linked_character_id=character.id,
                    level_id=level.level_number,
                    difficulty_tier=level.difficulty_tier,
                    verse_reference=reference,
                    verse_excerpt=excerpt,
                    image_asset_key=image_key,
                    image_alt_text=image_alt,
                    review_status=ReviewStatus.APPROVED,
                    active=True,
                    created_by=SEED_AUTHOR,
                )
            )
            created += 1

        level.character_pool = [
            str(characters[name].id) for name, *_ in {(item[0],) + tuple() for item in chosen}
        ]

    db.flush()
    return created


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Seed Anointed dev/QA content.")
    parser.add_argument(
        "--questions-per-level",
        type=int,
        default=settings.beta_min_questions_per_level,
        help="Approved+active questions to generate per level (default: beta minimum).",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Publish a content version afterwards so the practice pack is available.",
    )
    parser.add_argument(
        "--create-tables",
        action="store_true",
        help="Create tables directly instead of running Alembic first (dev convenience).",
    )
    args = parser.parse_args(argv)

    if args.create_tables:
        Base.metadata.create_all(engine)

    with SessionLocal() as db:
        levels = ensure_levels(db)
        characters = ensure_characters(db)
        created = generate_questions(
            db, characters, levels, per_level=args.questions_per_level
        )
        db.commit()

        total = int(db.execute(select(func.count()).select_from(Question)).scalar_one())
        print(
            f"Seeded {len(levels)} levels, {len(characters)} characters, "
            f"{created} new questions ({total} total)."
        )

        if args.publish:
            record, report = content_pack.publish(
                db,
                published_by=SEED_AUTHOR,
                change_summary="Seed content import",
                threshold=args.questions_per_level,
            )
            if record is None:
                db.rollback()
                print(f"Publish blocked: {report.summary()}", file=sys.stderr)
                return 1
            db.commit()
            print(
                f"Published content_version {record.content_version} "
                f"({record.pack_size_bytes:,} bytes gzipped, checksum {record.checksum[:12]}...)."
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
