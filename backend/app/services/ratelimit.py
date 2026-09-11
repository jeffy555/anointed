"""Fixed-window rate limiting backed by Postgres.

Limits come from design-spec §21 (phone-path abuse controls, ranked attempt caps).
Windows are stored in the database rather than process memory because the API runs
multiple worker processes on Railway/Render.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import RateLimitCounter


@dataclass(frozen=True)
class LimitResult:
    allowed: bool
    remaining: int
    retry_after_seconds: int


def _window_start(now: datetime, window: timedelta) -> datetime:
    seconds = int(window.total_seconds())
    epoch = int(now.timestamp())
    return datetime.fromtimestamp(epoch - (epoch % seconds), tz=timezone.utc)


def check_and_increment(
    db: Session,
    scope: str,
    key: str | None,
    *,
    limit: int,
    window: timedelta,
    now: datetime | None = None,
) -> LimitResult:
    """Consume one unit from ``scope``/``key`` for the current window.

    A missing key (no install id, no client IP) is treated as unlimited rather
    than as a shared bucket — pooling unknown callers into one counter would let
    one abuser lock out every legitimate user who also lacks the header.
    """
    if not key:
        return LimitResult(allowed=True, remaining=limit, retry_after_seconds=0)

    now = now or datetime.now(timezone.utc)
    start = _window_start(now, window)

    counter = db.execute(
        select(RateLimitCounter)
        .where(
            RateLimitCounter.scope == scope,
            RateLimitCounter.key == key,
            RateLimitCounter.window_start == start,
        )
        .with_for_update(nowait=False)
        if db.bind is not None and db.bind.dialect.name == "postgresql"
        else select(RateLimitCounter).where(
            RateLimitCounter.scope == scope,
            RateLimitCounter.key == key,
            RateLimitCounter.window_start == start,
        )
    ).scalar_one_or_none()

    retry_after = int((start + window - now).total_seconds())

    if counter is None:
        db.add(RateLimitCounter(scope=scope, key=key, window_start=start, count=1))
        db.flush()
        return LimitResult(allowed=True, remaining=limit - 1, retry_after_seconds=retry_after)

    if counter.count >= limit:
        return LimitResult(allowed=False, remaining=0, retry_after_seconds=max(retry_after, 1))

    counter.count += 1
    db.flush()
    return LimitResult(
        allowed=True, remaining=limit - counter.count, retry_after_seconds=retry_after
    )


def purge_expired(db: Session, older_than: timedelta = timedelta(days=2)) -> int:
    """Drop stale windows so the counter table stays small."""
    cutoff = datetime.now(timezone.utc) - older_than
    rows = db.execute(
        select(RateLimitCounter).where(RateLimitCounter.window_start < cutoff)
    ).scalars().all()
    for row in rows:
        db.delete(row)
    return len(rows)
