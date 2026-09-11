"""Force-upgrade gate — build order 0.2 (design-spec §16)."""

from __future__ import annotations

from tests.helpers import headers


def test_version_endpoint_reports_no_upgrade_for_current_build(client):
    response = client.get("/v1/version/minimum", headers=headers())
    assert response.status_code == 200
    body = response.json()
    assert body["force_upgrade_required"] is False
    assert body["minimum_version"] == "1.0.0"
    assert body["app_store_url"] and body["play_store_url"]


def test_version_endpoint_blocks_older_build(client):
    response = client.get(
        "/v1/version/minimum?installed_version=0.9.3", headers=headers()
    )
    assert response.json()["force_upgrade_required"] is True


def test_force_upgrade_event_is_recorded(client, db):
    from app.models.analytics import AnalyticsEvent

    client.get("/v1/version/minimum?installed_version=0.1.0", headers=headers())
    names = [row.event_name for row in db.query(AnalyticsEvent).all()]
    assert "force_upgrade_shown" in names


def test_unparseable_version_is_treated_as_below_minimum(client):
    """A malformed version must be blocked, not waved through."""
    response = client.get("/v1/version/minimum?installed_version=garbage", headers=headers())
    assert response.json()["force_upgrade_required"] is True


def test_version_check_needs_no_authentication(client):
    """M-01 calls this before any session exists."""
    response = client.get("/v1/version/minimum")
    assert response.status_code == 200
