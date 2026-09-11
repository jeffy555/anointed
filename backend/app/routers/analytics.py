"""Analytics ingestion — batched client events (analytics-spec §15).

The Flutter client queues events offline and flushes them here when connectivity
returns, so this endpoint accepts a batch rather than one event per request.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter
from pydantic import Field

from app.core.deps import Context, DbSession, OptionalUser
from app.models.enums import Platform
from app.schemas.common import ApiModel
from app.services import analytics as analytics_service

router = APIRouter(prefix="/v1/analytics", tags=["analytics"])

MAX_BATCH = 100


class ClientEvent(ApiModel):
    event_name: str = Field(min_length=1, max_length=64)
    session_id: str | None = Field(default=None, max_length=64)
    # Client-side occurrence time. The server also stamps its own receipt time;
    # this one is kept in properties so offline-queued events stay orderable.
    occurred_at: datetime | None = None
    properties: dict[str, Any] = Field(default_factory=dict)


class EventBatchRequest(ApiModel):
    events: list[ClientEvent] = Field(min_length=1, max_length=MAX_BATCH)


class EventBatchResponse(ApiModel):
    accepted: int
    dropped: int


@router.post("/events", response_model=EventBatchResponse)
def ingest_events(
    payload: EventBatchRequest, user: OptionalUser, db: DbSession, context: Context
) -> EventBatchResponse:
    valid_platforms = {item.value for item in Platform}
    platform = Platform(context.platform) if context.platform in valid_platforms else None

    accepted = 0
    for event in payload.events:
        properties = dict(event.properties)
        if event.occurred_at is not None:
            properties["client_occurred_at"] = event.occurred_at.isoformat()

        recorded = analytics_service.track(
            db,
            event.event_name,
            user=user,
            session_id=event.session_id or context.session_id,
            platform=platform,
            app_version=context.app_version,
            os_version=context.os_version,
            device_type=context.device_type,
            properties=properties,
        )
        if recorded is not None:
            accepted += 1

    return EventBatchResponse(accepted=accepted, dropped=len(payload.events) - accepted)
