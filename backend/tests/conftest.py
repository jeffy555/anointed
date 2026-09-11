"""Test fixtures. Each test gets an isolated SQLite database and a fresh app."""

from __future__ import annotations

import os
import tempfile
from collections.abc import Iterator

import pytest

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("JWT_SECRET", "test-secret")


@pytest.fixture()
def db_url() -> Iterator[str]:
    handle = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    handle.close()
    yield f"sqlite+pysqlite:///{handle.name}"
    try:
        os.unlink(handle.name)
    except OSError:
        pass


@pytest.fixture()
def app_context(db_url, monkeypatch):
    """Rebuild the app against a throwaway database.

    ``app.core.database`` binds its engine at import time, so the settings cache and
    every module that captured the engine have to be reloaded for each test.
    """
    import importlib
    import sys

    monkeypatch.setenv("DATABASE_URL", db_url)
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("JWT_SECRET", "test-secret")
    monkeypatch.setenv("ADMIN_SESSION_SECRET", "test-admin-secret")
    # Leave every third-party credential unset so tests exercise the dev-fallback
    # branch of each integration rather than reaching out to a real provider.
    # Apple is the exception that needs clearing: its audience defaults to the
    # bundle id, which would otherwise make it look configured.
    monkeypatch.setenv("APPLE_BUNDLE_IDS", "")

    for name in [key for key in list(sys.modules) if key.startswith("app.")] + ["app"]:
        sys.modules.pop(name, None)

    from app.core import config

    config.get_settings.cache_clear()
    importlib.reload(config)

    from app.core import database

    importlib.reload(database)

    import app.models  # noqa: F401

    database.Base.metadata.create_all(database.engine)

    from app.main import app as fastapi_app

    yield fastapi_app

    database.Base.metadata.drop_all(database.engine)
    database.engine.dispose()


@pytest.fixture()
def client(app_context):
    from fastapi.testclient import TestClient

    with TestClient(app_context) as test_client:
        yield test_client


@pytest.fixture()
def db(app_context):
    from app.core.database import SessionLocal

    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def seeded(db):
    """A small but rule-satisfying content pool: 6 levels, 12 questions each."""
    from app.models.content import BibleCharacter, Level, Question
    from app.models.enums import DifficultyTier, ReviewStatus, Testament, VariantType

    characters = []
    for index in range(8):
        character = BibleCharacter(
            name=f"Character {index}",
            testament=Testament.OLD,
            review_status=ReviewStatus.APPROVED,
        )
        db.add(character)
        characters.append(character)
    db.flush()

    for number in range(1, 7):
        db.add(
            Level(
                level_number=number,
                title=f"Level {number}",
                timer_seconds=60,
                difficulty_tier=DifficultyTier.EASY,
                is_free_tier=number <= 5,
                min_questions_required=10,
            )
        )
    db.flush()

    for number in range(1, 7):
        for index in range(12):
            character = characters[index % len(characters)]
            others = [item.name for item in characters if item.name != character.name][:3]
            variant = VariantType.VERSE_CLUE if index % 3 == 0 else VariantType.TEXT_QA
            db.add(
                Question(
                    question_text=f"L{number} Q{index}: who is this?",
                    variant_type=variant,
                    answer_options=[character.name, *others],
                    correct_answer=character.name,
                    linked_character_id=character.id,
                    level_id=number,
                    difficulty_tier=DifficultyTier.EASY,
                    verse_reference="Genesis 1:1" if variant == VariantType.VERSE_CLUE else None,
                    verse_excerpt="In the beginning..."
                    if variant == VariantType.VERSE_CLUE
                    else None,
                    review_status=ReviewStatus.APPROVED,
                    active=True,
                )
            )
    db.commit()
    return True
