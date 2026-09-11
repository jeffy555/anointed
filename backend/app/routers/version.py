"""Force-upgrade gate — build order 0.2.

The mobile client calls this before any other API call on every cold launch
(architecture §4.4).
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Query

from app.core.config import settings
from app.core.deps import Context, DbSession
from app.core.versioning import is_below_minimum
from app.models.enums import Platform
from app.schemas.common import MinimumVersionResponse
from app.services import analytics

router = APIRouter(prefix="/v1/version", tags=["version"])


@router.get("/minimum", response_model=MinimumVersionResponse)
def minimum_version(
    db: DbSession,
    context: Context,
    installed_version: str | None = Query(
        default=None,
        description="Installed app version. When supplied the server decides "
        "force_upgrade_required so the client does not have to compare semver itself.",
    ),
) -> MinimumVersionResponse:
    installed = installed_version or context.app_version
    required = bool(installed) and is_below_minimum(installed, settings.minimum_app_version)

    if required:
        analytics.track(
            db,
            "force_upgrade_shown",
            session_id=context.session_id,
            platform=Platform(context.platform) if _valid_platform(context.platform) else None,
            app_version=installed,
            os_version=context.os_version,
            device_type=context.device_type,
            properties={
                "installed_version": installed,
                "minimum_version": settings.minimum_app_version,
            },
        )

    return MinimumVersionResponse(
        minimum_version=settings.minimum_app_version,
        current_store_version=settings.current_store_version,
        minimum_app_build=settings.minimum_app_build,
        force_upgrade_required=required,
        release_notes=settings.force_upgrade_release_notes or None,
        app_store_url=settings.app_store_url,
        play_store_url=settings.play_store_url,
        server_time_utc=datetime.now(timezone.utc),
    )


def _valid_platform(value: str | None) -> bool:
    return value in {item.value for item in Platform}
