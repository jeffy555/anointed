"""Column types that behave the same on PostgreSQL (production) and SQLite (tests)."""

from __future__ import annotations

import uuid

from sqlalchemy import JSON, Uuid
from sqlalchemy.dialects.postgresql import JSONB

# JSONB on Postgres for indexable payloads; plain JSON elsewhere.
JsonB = JSON().with_variant(JSONB, "postgresql")

# Native uuid on Postgres, CHAR(32) elsewhere.
UuidPk = Uuid(as_uuid=True)


def new_uuid() -> uuid.UUID:
    return uuid.uuid4()
