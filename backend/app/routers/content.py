"""Practice content sync — build order B.9 (design-spec §19).

Both endpoints are session-authed but deliberately *not* consent-gated: a pending
child account still needs its practice pack, and the pack contains no personal data.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.core.deps import Context, CurrentUser, DbSession
from app.models.content import BibleCharacter
from app.models.enums import Platform
from app.schemas.common import ApiModel
from app.services import analytics, character_assets, content_pack

router = APIRouter(prefix="/v1/content", tags=["content"])


class ManifestResponse(ApiModel):
    content_version: int
    published_at: datetime | None
    pack_size_bytes: int
    checksum: str | None
    min_app_build: int
    change_summary: str | None


@router.get("/manifest", response_model=ManifestResponse)
def manifest(
    user: CurrentUser,
    db: DbSession,
    context: Context,
    local_content_version: int = Query(
        default=0, ge=0, description="Client's current pack version, for the analytics event."
    ),
) -> ManifestResponse:
    """Cheap freshness check on online cold launch and on M-18 entry after 24h."""
    record = content_pack.current_publish(db)
    server_version = record.content_version if record else 0

    valid_platforms = {item.value for item in Platform}
    analytics.track(
        db,
        "content_manifest_checked",
        user=user,
        session_id=context.session_id,
        platform=Platform(context.platform) if context.platform in valid_platforms else None,
        app_version=context.app_version,
        properties={
            "server_content_version": server_version,
            "local_content_version": local_content_version,
            "update_needed": server_version > local_content_version,
        },
    )

    return ManifestResponse(
        content_version=server_version,
        published_at=record.published_at if record else None,
        pack_size_bytes=record.pack_size_bytes if record else 0,
        checksum=record.checksum if record else None,
        min_app_build=record.min_app_build if record else 1,
        change_summary=record.change_summary if record else None,
    )


@router.get("/practice-pack")
def practice_pack(
    user: CurrentUser,
    db: DbSession,
    since_version: int = Query(default=0, ge=0),
) -> Response:
    """Full gzipped pack. 204 when the client is already current (§19 API surface).

    v1 is full-pack replacement, not delta updates.
    """
    record = content_pack.current_publish(db)
    if record is None:
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    if since_version >= record.content_version:
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    body = content_pack.gzip_pack(record.pack_json)
    return Response(
        content=body,
        media_type="application/json",
        headers={
            "Content-Encoding": "gzip",
            "X-Content-Version": str(record.content_version),
            "X-Content-Checksum": record.checksum,
            "Cache-Control": "no-transform, max-age=300",
        },
    )


@router.get("/assets/{asset_key:path}")
def asset(
    asset_key: str,
    user: CurrentUser,
    db: DbSession,
) -> Response:
    """SVG character portraits for ``image_clue`` gameplay (design-spec §18H)."""
    del user
    character_names = {
        character.name: character_assets.asset_key_for_character(character.name)
        for character in db.execute(select(BibleCharacter)).scalars().all()
    }
    body = character_assets.resolve_asset(asset_key, character_names=character_names)
    if body is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="asset_not_found")
    return Response(
        content=body,
        media_type="image/svg+xml",
        headers={"Cache-Control": "public, max-age=86400"},
    )
