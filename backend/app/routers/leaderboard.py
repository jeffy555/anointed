"""Leaderboard — build order B.6. Read-only; there is no client write endpoint (§21)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Query
from sqlalchemy import func, select

from app.core.deps import ConsentedUser, Context, DbSession
from app.models.enums import Platform
from app.models.gameplay import LeaderboardEntry
from app.schemas.common import ApiModel
from app.services import analytics

router = APIRouter(prefix="/v1/leaderboard", tags=["leaderboard"])

Window = Literal["all_time", "weekly", "daily"]


class LeaderboardRow(ApiModel):
    rank: int
    display_name: str
    score: int
    level_id: int
    recorded_at: datetime
    is_current_user: bool


class YourRank(ApiModel):
    rank: int | None
    score: int | None
    display_name: str
    level_id: int | None


class LeaderboardResponse(ApiModel):
    window: Window
    rows: list[LeaderboardRow]
    your_rank: YourRank
    total_entries: int
    generated_at: datetime


def _window_start(window: Window) -> datetime | None:
    now = datetime.now(timezone.utc)
    if window == "daily":
        return now.replace(hour=0, minute=0, second=0, microsecond=0)
    if window == "weekly":
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return start_of_day - timedelta(days=start_of_day.weekday())
    return None


@router.get("", response_model=LeaderboardResponse)
def read_leaderboard(
    user: ConsentedUser,
    db: DbSession,
    context: Context,
    window: Window = Query(default="all_time"),
    limit: int = Query(default=50, ge=1, le=200),
    entry_source: str = Query(default="nav_tab"),
) -> LeaderboardResponse:
    """M-17. Each user's single best entry is ranked, not every attempt.

    Otherwise one player replaying a level would fill the whole board.
    UTC boundaries per backend.timezoneHandling; the client renders local time.
    """
    start = _window_start(window)

    best_per_user = (
        select(
            LeaderboardEntry.user_id.label("user_id"),
            func.max(LeaderboardEntry.score).label("best_score"),
        )
        .where(LeaderboardEntry.revoked.is_(False))
        .group_by(LeaderboardEntry.user_id)
    )
    if start is not None:
        best_per_user = best_per_user.where(LeaderboardEntry.recorded_at >= start)
    best_per_user = best_per_user.subquery()

    ranked = (
        select(LeaderboardEntry)
        .join(
            best_per_user,
            (LeaderboardEntry.user_id == best_per_user.c.user_id)
            & (LeaderboardEntry.score == best_per_user.c.best_score),
        )
        .where(LeaderboardEntry.revoked.is_(False))
        .order_by(LeaderboardEntry.score.desc(), LeaderboardEntry.recorded_at.asc())
        .limit(limit)
    )
    if start is not None:
        ranked = ranked.where(LeaderboardEntry.recorded_at >= start)

    entries = list(db.execute(ranked).scalars().all())

    # Deduplicate: a user can tie their own best score on two attempts.
    seen: set = set()
    rows: list[LeaderboardRow] = []
    for entry in entries:
        if entry.user_id in seen:
            continue
        seen.add(entry.user_id)
        rows.append(
            LeaderboardRow(
                rank=len(rows) + 1,
                display_name=entry.display_name,
                score=entry.score,
                level_id=entry.level_id,
                recorded_at=entry.recorded_at,
                is_current_user=entry.user_id == user.id,
            )
        )

    your_best_query = select(LeaderboardEntry).where(
        LeaderboardEntry.user_id == user.id, LeaderboardEntry.revoked.is_(False)
    )
    if start is not None:
        your_best_query = your_best_query.where(LeaderboardEntry.recorded_at >= start)
    your_best = db.execute(
        your_best_query.order_by(LeaderboardEntry.score.desc())
    ).scalars().first()

    your_rank_value: int | None = None
    if your_best is not None:
        better = select(func.count(func.distinct(LeaderboardEntry.user_id))).where(
            LeaderboardEntry.revoked.is_(False), LeaderboardEntry.score > your_best.score
        )
        if start is not None:
            better = better.where(LeaderboardEntry.recorded_at >= start)
        your_rank_value = int(db.execute(better).scalar_one()) + 1

    total_query = select(func.count(func.distinct(LeaderboardEntry.user_id))).where(
        LeaderboardEntry.revoked.is_(False)
    )
    if start is not None:
        total_query = total_query.where(LeaderboardEntry.recorded_at >= start)
    total = int(db.execute(total_query).scalar_one())

    valid_platforms = {item.value for item in Platform}
    analytics.track(
        db,
        "leaderboard_viewed",
        user=user,
        session_id=context.session_id,
        platform=Platform(context.platform) if context.platform in valid_platforms else None,
        properties={
            "connectivity": "online",
            "entry_source": entry_source,
            "user_rank": your_rank_value,
        },
    )

    return LeaderboardResponse(
        window=window,
        rows=rows,
        your_rank=YourRank(
            rank=your_rank_value,
            score=your_best.score if your_best else None,
            display_name=user.leaderboard_display_name,
            level_id=your_best.level_id if your_best else None,
        ),
        total_entries=total,
        generated_at=datetime.now(timezone.utc),
    )
