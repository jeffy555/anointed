"""Kids Zone progress sync.

One endpoint, and it merges rather than replaces. The client posts everything it
holds locally and gets back the union; the server keeps whichever star rating is
higher per stop. That makes the call idempotent and order-independent, which is
what lets Kids Zone stay playable offline without a pending-write queue on the
device: a failed sync needs no bookkeeping, because the next one carries the same
state again.

Merging also handles the case the whole feature exists for — a child who played
on one device signing in on another, or after the sign-out wipe. Neither side is
authoritative, so neither side can erase the other's stars.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from pydantic import Field
from sqlalchemy import select

from app.core.database import utcnow
from app.core.deps import ConsentedUser, Context, DbSession
from app.models.kids_zone import MAX_STARS, KidsZoneStopCompletion
from app.schemas.common import ApiModel
from app.services import analytics

router = APIRouter(prefix="/v1/kids-zone", tags=["kids-zone"])

# A child cannot plausibly finish more stops than the catalogue holds, and an
# unbounded list would let one request write arbitrarily many rows.
MAX_STOPS_PER_SYNC = 200


class StopProgress(ApiModel):
    stop_id: str = Field(max_length=64)
    adventure_id: str = Field(max_length=64)
    stars: int = Field(ge=0, le=MAX_STARS)


class SyncRequest(ApiModel):
    stops: list[StopProgress] = Field(default_factory=list, max_length=MAX_STOPS_PER_SYNC)


class SyncedStop(ApiModel):
    stop_id: str
    adventure_id: str
    stars: int
    last_completed_at: datetime


class SyncResponse(ApiModel):
    stops: list[SyncedStop]


@router.post("/progress/sync", response_model=SyncResponse)
def sync_progress(
    payload: SyncRequest,
    user: ConsentedUser,
    db: DbSession,
    context: Context,
) -> SyncResponse:
    """Merge the device's Kids Zone progress with the server's and return the union."""
    existing: dict[str, KidsZoneStopCompletion] = {
        row.stop_id: row
        for row in db.scalars(
            select(KidsZoneStopCompletion).where(
                KidsZoneStopCompletion.user_id == user.id
            )
        )
    }

    # Last write wins within a single payload, but only upward: a malformed
    # request repeating a stop cannot lower a star already earned.
    newly_completed = 0
    for incoming in payload.stops:
        row = existing.get(incoming.stop_id)
        if row is None:
            row = KidsZoneStopCompletion(
                user_id=user.id,
                stop_id=incoming.stop_id,
                adventure_id=incoming.adventure_id,
                best_stars=incoming.stars,
                completions_count=1,
            )
            db.add(row)
            existing[incoming.stop_id] = row
            newly_completed += 1
            continue

        if incoming.stars > row.best_stars:
            row.best_stars = incoming.stars
            row.last_completed_at = utcnow()

    db.commit()

    if newly_completed:
        analytics.track(
            db,
            "kids_zone_progress_synced",
            user=user,
            session_id=context.session_id,
            properties={"stops_added": newly_completed},
        )

    return SyncResponse(
        stops=[
            SyncedStop(
                stop_id=row.stop_id,
                adventure_id=row.adventure_id,
                stars=row.best_stars,
                last_completed_at=row.last_completed_at,
            )
            for row in sorted(existing.values(), key=lambda r: r.stop_id)
        ]
    )
