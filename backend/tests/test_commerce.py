"""IAP unlock and ad policy — build order B.7 and B.8."""

from __future__ import annotations

import pytest

from tests.helpers import headers, onboarded_adult, play_level, sign_up_phone


@pytest.fixture()
def adult(client, seeded) -> str:
    return onboarded_adult(client)


@pytest.fixture()
def child(client, seeded) -> str:
    """An under-13 account that has completed the full VPC + onboarding flow."""
    signup = sign_up_phone(client, name="Mia Small", age=10, mobile="+919000000200")
    token = signup["session_token"]
    client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:mum-sub:mum@example.com:Mum Small",
            "parent_guardian_name": "Mum Small",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
        },
        headers=headers(token),
    )
    client.post(
        "/v1/consent/child-notice/acknowledge",
        json={"acknowledged_by": "parent"},
        headers=headers(token),
    )
    client.post("/v1/auth/privacy-accept", json={"accepted": True}, headers=headers(token))
    return token


# ---------------------------------------------------------------------------- IAP
def test_product_endpoint_describes_the_single_unlock(client, adult):
    body = client.get("/v1/iap/product", headers=headers(adult)).json()
    assert body["unlocks_levels_from"] == 6
    assert body["unlocks_levels_to"] == 100
    assert body["free_tier_max_level"] == 5
    assert body["already_purchased"] is False


def test_nothing_to_restore_before_a_purchase(client, adult):
    body = client.get("/v1/iap/status", headers=headers(adult)).json()
    assert body["has_unlock"] is False
    assert body["outcome"] == "nothing_to_restore"


def test_dev_receipt_grants_the_unlock_and_opens_paid_levels(client, adult):
    for level in range(1, 6):
        play_level(client, adult, level)

    locked = client.post(
        "/v1/game/levels/6/attempts/start", json={"mode": "ranked"}, headers=headers(adult)
    )
    assert locked.status_code == 403

    validated = client.post(
        "/v1/iap/validate",
        json={
            "store": "google_play",
            "receipt": "devreceipt:txn-1001",
            "trigger": "level_5_complete",
        },
        headers=headers(adult),
    )
    assert validated.status_code == 200, validated.text
    body = validated.json()
    assert body["outcome"] == "success"
    assert body["has_unlock"] is True
    # The dev fallback must never claim the store confirmed anything.
    assert body["validated_by_provider"] is False

    unlocked = client.post(
        "/v1/game/levels/6/attempts/start", json={"mode": "ranked"}, headers=headers(adult)
    )
    assert unlocked.status_code == 201


def test_garbage_receipt_is_rejected_without_granting_anything(client, adult):
    body = client.post(
        "/v1/iap/validate",
        json={"store": "app_store", "receipt": "not-a-receipt"},
        headers=headers(adult),
    ).json()
    assert body["outcome"] == "invalid"
    assert body["has_unlock"] is False


def test_empty_receipt_is_a_bad_request(client, adult):
    response = client.post(
        "/v1/iap/validate",
        json={"store": "app_store", "receipt": "   "},
        headers=headers(adult),
    )
    assert response.status_code == 400
    assert response.json()["code"] == "receipt_missing"


def test_restoring_the_same_receipt_is_idempotent(client, adult):
    payload = {"store": "app_store", "receipt": "devreceipt:txn-2002", "trigger": "restore"}
    first = client.post("/v1/iap/validate", json=payload, headers=headers(adult)).json()
    second = client.post("/v1/iap/validate", json=payload, headers=headers(adult)).json()
    assert first["outcome"] == second["outcome"] == "success"

    from app.core.database import SessionLocal
    from app.models.commerce import PurchaseRecord

    with SessionLocal() as session:
        assert session.query(PurchaseRecord).count() == 1


def test_a_receipt_claimed_by_another_account_is_refused(client, adult, seeded):
    payload = {"store": "app_store", "receipt": "devreceipt:txn-3003"}
    client.post("/v1/iap/validate", json=payload, headers=headers(adult))

    other = onboarded_adult(client, name="Second Player", mobile="+919000000300")
    response = client.post("/v1/iap/validate", json=payload, headers=headers(other))
    assert response.status_code == 409
    assert response.json()["code"] == "receipt_already_used"


# ---------------------------------------------------------------------------- ads
def test_adults_get_ad_config_with_the_documented_caps(client, adult):
    body = client.get("/v1/ads/config", headers=headers(adult)).json()
    assert body["ads_enabled"] is True
    assert body["tag_for_child_directed_treatment"] is False
    assert body["every_nth_level"] == 3
    assert body["max_per_session"] == 2
    assert body["min_level"] == 4


def test_under_13_accounts_are_entirely_ad_free(client, child):
    body = client.get("/v1/ads/config", headers=headers(child)).json()
    assert body["ads_enabled"] is False
    assert body["tag_for_child_directed_treatment"] is True
    assert body["personalized_ads"] is False
    # No unit ids at all, so a client ignoring the flag still cannot request an ad.
    assert body["interstitial_unit_id"] is None
    assert body["app_id"] is None


def test_an_ad_event_from_an_under_13_client_is_rejected(client, child):
    response = client.post(
        "/v1/ads/events",
        json={"event": "viewed", "ad_format": "interstitial", "level_id": 4},
        headers=headers(child),
    )
    assert response.status_code == 403
    assert response.json()["code"] == "ads_not_permitted"


def test_ad_events_from_adults_are_logged(client, adult, db):
    from app.models.commerce import AdImpressionLog

    response = client.post(
        "/v1/ads/events",
        json={"event": "viewed", "ad_unit_id": "unit-1", "level_id": 4},
        headers=headers(adult),
    )
    assert response.status_code == 200
    log = db.query(AdImpressionLog).one()
    assert log.clicked is False
    assert log.is_child_directed is False


def test_paying_users_still_see_ads_only_under_the_stated_rules(client, adult):
    """Purchase removes the paywall, not the ad policy (design-spec §20)."""
    client.post(
        "/v1/iap/validate",
        json={"store": "app_store", "receipt": "devreceipt:txn-ads"},
        headers=headers(adult),
    )
    body = client.get("/v1/ads/config", headers=headers(adult)).json()
    assert body["ads_enabled"] is True


def test_production_ads_disabled_without_coppa_ack(client, adult, monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "environment", "production")
    monkeypatch.setattr(settings, "admob_production_ack", False)
    body = client.get("/v1/ads/config", headers=headers(adult)).json()
    assert body["ads_enabled"] is False
    assert body["interstitial_unit_id"] is None


def test_interstitial_frequency_rules(client, adult, child, db):
    """design-spec §20: every 3rd completion, max 2 per session, never before level 4."""
    from app.models.enums import AttemptMode
    from app.models.user import User
    from app.services.ads import interstitial_eligible

    grown_up = db.query(User).filter(User.mobile == "919876543210").one()
    kid = db.query(User).filter(User.mobile == "919000000200").one()

    def eligible(user, level, completed, shown, mode=AttemptMode.RANKED):
        return interstitial_eligible(
            user,
            level_number=level,
            mode=mode,
            levels_completed_this_session=completed,
            ads_shown_this_session=shown,
        )

    assert eligible(grown_up, 6, 3, 0) is True
    assert eligible(grown_up, 2, 3, 0) is False, "levels 1-3 are ad-free"
    assert eligible(grown_up, 6, 4, 0) is False, "only every 3rd completion"
    assert eligible(grown_up, 6, 6, 2) is False, "session cap of 2"
    assert eligible(grown_up, 6, 3, 0, AttemptMode.PRACTICE) is False, "practice has no ads"
    assert eligible(kid, 6, 3, 0) is False, "under-13 is never eligible"
