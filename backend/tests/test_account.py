"""Profile, settings, support, and account deletion — build order B.11 (M-26–M-31)."""

from __future__ import annotations

import pytest

from tests.helpers import headers, onboarded_adult, play_level


@pytest.fixture()
def token(client, seeded) -> str:
    return onboarded_adult(client)


def test_profile_reflects_progress_and_entitlements(client, token):
    play_level(client, token, 1)
    body = client.get("/v1/account/profile", headers=headers(token)).json()
    assert body["name"] == "Ada Lovelace"
    assert body["levels_completed"] == 1
    assert body["highest_level_completed"] == 1
    assert body["total_score"] > 0
    assert body["has_unlock"] is False
    assert body["support_email"]


def test_notification_opt_in_round_trips(client, token):
    """B.10: the opt-in lives server-side so it survives a reinstall."""
    assert client.get("/v1/account/profile", headers=headers(token)).json()[
        "notifications_opt_in"
    ] in (True, False)

    updated = client.patch(
        "/v1/account/settings", json={"notifications_opt_in": True}, headers=headers(token)
    ).json()
    assert updated["notifications_opt_in"] is True

    reread = client.get("/v1/account/profile", headers=headers(token)).json()
    assert reread["notifications_opt_in"] is True


def test_faq_is_served_from_the_backend(client, token):
    body = client.get("/v1/account/faq", headers=headers(token)).json()
    assert len(body["items"]) >= 5
    assert any(item["id"] == "account-delete" for item in body["items"])


def test_support_request_is_persisted_even_without_an_email_provider(client, token, db):
    from app.models.user import SupportRequest

    response = client.post(
        "/v1/account/support",
        json={"subject_category": "purchase", "message": "I paid but nothing unlocked."},
        headers=headers(token),
    )
    assert response.status_code == 200
    row = db.query(SupportRequest).one()
    assert row.subject_category == "purchase"
    assert row.delivered is False


def test_completions_list_supports_offline_rehydration(client, token):
    play_level(client, token, 1)
    play_level(client, token, 2)
    assert client.get("/v1/account/completions", headers=headers(token)).json() == [1, 2]


# ------------------------------------------------------------------- deletion
def test_deletion_preview_states_what_goes_and_what_stays(client, token):
    play_level(client, token, 1)
    body = client.get("/v1/account/deletion-preview", headers=headers(token)).json()
    assert body["levels_completed"] == 1
    assert body["removed"] and body["retained_anonymized"]
    assert "cannot be undone" in body["warning"]


def test_deletion_requires_both_confirmations(client, token):
    response = client.post(
        "/v1/account/delete", json={"confirm": True}, headers=headers(token)
    )
    assert response.status_code == 400
    assert response.json()["code"] == "confirmation_required"


def test_deletion_removes_pii_and_anonymises_the_rest(client, token, db):
    from app.models.analytics import AnalyticsEvent, AuditLog
    from app.models.commerce import PurchaseRecord
    from app.models.consent import ParentalConsentRecord
    from app.models.gameplay import LeaderboardEntry, LevelAttempt
    from app.models.user import AuthIdentity, LevelCompletion, User, UserProgress

    play_level(client, token, 1)
    client.post(
        "/v1/iap/validate",
        json={"store": "app_store", "receipt": "devreceipt:txn-del"},
        headers=headers(token),
    )

    response = client.post(
        "/v1/account/delete",
        json={"confirm": True, "acknowledged_permanent": True},
        headers=headers(token),
    )
    assert response.status_code == 200, response.text
    assert response.json()["deleted"] is True

    db.expire_all()
    # Every table that holds identifying data is empty.
    assert db.query(User).count() == 0
    assert db.query(AuthIdentity).count() == 0
    assert db.query(UserProgress).count() == 0
    assert db.query(LevelCompletion).count() == 0
    assert db.query(LevelAttempt).count() == 0
    assert db.query(LeaderboardEntry).count() == 0
    assert db.query(ParentalConsentRecord).count() == 0

    # The purchase survives for refund disputes, but with nothing pointing at a person.
    purchase = db.query(PurchaseRecord).one()
    assert purchase.user_id is None
    assert purchase.receipt_token is None
    assert purchase.transaction_id == "txn-del"

    # Analytics rows survive so funnels stay correct, detached from the user.
    assert db.query(AnalyticsEvent).count() > 0
    assert db.query(AnalyticsEvent).filter(AnalyticsEvent.user_id.is_not(None)).count() == 0

    # A compliance record of the deletion itself remains.
    assert db.query(AuditLog).filter(AuditLog.action == "user_account_deleted").count() == 1


def test_the_session_token_stops_working_after_deletion(client, token):
    client.post(
        "/v1/account/delete",
        json={"confirm": True, "acknowledged_permanent": True},
        headers=headers(token),
    )
    assert client.get("/v1/account/profile", headers=headers(token)).status_code == 401


def test_deleting_frees_the_phone_number_for_reuse(client, token, seeded):
    client.post(
        "/v1/account/delete",
        json={"confirm": True, "acknowledged_permanent": True},
        headers=headers(token),
    )
    again = client.post(
        "/v1/auth/phone/signup",
        json={"mobile": "+919876543210", "name": "Ada Lovelace", "age": 30},
        headers=headers(),
    )
    assert again.status_code == 201


def test_deleting_a_child_account_also_removes_the_consent_record(client, seeded, db):
    from app.models.analytics import AuditLog
    from app.models.consent import ParentalConsentRecord

    from tests.helpers import sign_up_phone

    kid = sign_up_phone(client, name="Sam Small", age=9, mobile="+919000000500")
    kid_token = kid["session_token"]
    client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:dad-sub:dad@example.com:Dad Small",
            "parent_guardian_name": "Dad Small",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
        },
        headers=headers(kid_token),
    )
    assert db.query(ParentalConsentRecord).count() == 1

    client.post(
        "/v1/account/delete",
        json={"confirm": True, "acknowledged_permanent": True},
        headers=headers(kid_token),
    )
    db.expire_all()
    assert db.query(ParentalConsentRecord).count() == 0
    audit = (
        db.query(AuditLog).filter(AuditLog.action == "user_account_deleted").one()
    )
    assert audit.target_is_under_13 is True


def test_abandoned_pending_child_accounts_are_purged(client, seeded, db):
    """design-spec §11 retention: 14 days pending, then the PII goes."""
    from datetime import datetime, timedelta, timezone

    from app.models.user import User
    from app.services import accounts

    from tests.helpers import sign_up_phone

    sign_up_phone(client, name="Never Consented", age=7, mobile="+919000000600")
    db.expire_all()
    user = db.query(User).filter(User.mobile == "919000000600").one()
    user.created_at = datetime.now(timezone.utc) - timedelta(days=30)
    db.commit()

    assert accounts.cleanup_abandoned_pending_accounts(db) == 1
    db.commit()
    assert db.query(User).filter(User.mobile == "919000000600").count() == 0
