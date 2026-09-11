"""Shared response/request schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ApiModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class MessageResponse(ApiModel):
    code: str
    message: str


class MinimumVersionResponse(ApiModel):
    minimum_version: str
    current_store_version: str
    minimum_app_build: int
    force_upgrade_required: bool
    release_notes: str | None = None
    app_store_url: str
    play_store_url: str
    server_time_utc: datetime
