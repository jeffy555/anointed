"""Kids Zone progress.

Kids Zone used to be the only player-visible progress with no server copy: stars
and completed stops lived in the device's SharedPreferences and nowhere else, and
`clearAccountScopedState()` wipes them on sign-out (deliberately, so a shared
family device does not hand one child another's adventures). With no server
copy, that wipe destroyed the record instead of re-syncing it.

Deliberately *not* modelled on `LevelAttempt`: Main Journey is server-scored
because it is ranked, and `game.py` refuses a client-supplied score for that
reason. Kids Zone mini-games run entirely on-device, have no leaderboard and no
ranked standing, so the client is the only thing that can report a star rating.
The server clamps the value and keeps the best, which is the whole of the trust
model here — worth stating plainly so nobody later mistakes this table for a
precedent that ranked scores may be client-supplied.
"""

from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, timestamp_column, utcnow

MAX_STARS = 3


class KidsZoneStopCompletion(Base):
    """One row per (user, stop) the child has finished at least once."""

    __tablename__ = "kids_zone_stop_completions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    stop_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    adventure_id: Mapped[str] = mapped_column(String(64), nullable=False)
    best_stars: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completions_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    first_completed_at = timestamp_column(default=utcnow, nullable=False)
    last_completed_at = timestamp_column(default=utcnow, nullable=False)
