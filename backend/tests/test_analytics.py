"""Analytics ingestion and its privacy guardrails (analytics-spec §2, §4)."""

from __future__ import annotations

import pytest

from tests.helpers import headers, onboarded_adult, play_level, sign_up_phone


@pytest.fixture()
def token(client, seeded) -> str:
    return onboarded_adult(client)


def test_health_endpoint(client):
    assert client.get("/health").json()["status"] == "ok"


def test_client_batch_is_ingested(client, token, db):
    from app.models.analytics import AnalyticsEvent

    response = client.post(
        "/v1/analytics/events",
        json={
            "events": [
                {"event_name": "screen_view", "properties": {"screen_id": "M-11"}},
                {"event_name": "screen_view", "properties": {"screen_id": "M-17"}},
            ]
        },
        headers=headers(token),
    )
    assert response.status_code == 200
    assert response.json() == {"accepted": 2, "dropped": 0}
    assert db.query(AnalyticsEvent).filter(AnalyticsEvent.event_name == "screen_view").count() == 2


def test_pii_is_stripped_from_event_properties(client, token, db):
    from app.models.analytics import AnalyticsEvent

    client.post(
        "/v1/analytics/events",
        json={
            "events": [
                {
                    "event_name": "screen_view",
                    "properties": {
                        "screen_id": "M-26",
                        "name": "Ada Lovelace",
                        "mobile": "+919876543210",
                        "email": "ada@example.com",
                    },
                }
            ]
        },
        headers=headers(token),
    )
    event = db.query(AnalyticsEvent).filter(AnalyticsEvent.event_name == "screen_view").one()
    assert event.properties == {"screen_id": "M-26"}


def test_pending_consent_accounts_only_emit_onboarding_events(client, seeded, db):
    """analytics-spec §4: no gameplay telemetry before a parent consents."""
    from app.models.analytics import AnalyticsEvent

    kid = sign_up_phone(client, name="Pending Kid", age=8, mobile="+919000000700")
    response = client.post(
        "/v1/analytics/events",
        json={
            "events": [
                {"event_name": "screen_view", "properties": {}},
                {"event_name": "level_started", "properties": {"level_id": 1}},
                {"event_name": "ad_viewed", "properties": {}},
            ]
        },
        headers=headers(kid["session_token"]),
    )
    assert response.json() == {"accepted": 1, "dropped": 2}
    assert db.query(AnalyticsEvent).filter(AnalyticsEvent.event_name == "level_started").count() == 0


def test_gameplay_emits_the_specified_funnel_events(client, token, db):
    from app.models.analytics import AnalyticsEvent

    play_level(client, token, 1)
    names = {row.event_name for row in db.query(AnalyticsEvent).all()}
    assert {"level_started", "question_answered", "level_completed", "leaderboard_submitted"} <= names


def test_anonymous_events_are_accepted(client, seeded):
    """The client fires session_start before any account exists."""
    response = client.post(
        "/v1/analytics/events",
        json={"events": [{"event_name": "app_open", "properties": {}}]},
        headers=headers(),
    )
    assert response.json()["accepted"] == 1


def test_oversized_batches_are_rejected(client, token):
    response = client.post(
        "/v1/analytics/events",
        json={"events": [{"event_name": "screen_view", "properties": {}}] * 101},
        headers=headers(token),
    )
    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"
