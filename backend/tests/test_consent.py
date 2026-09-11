"""Verifiable parental consent — build order B.2 (design-spec §11)."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from tests.helpers import headers, sign_up_phone


@pytest.fixture()
def child(client):
    """An under-13 account sitting in pending_parental_consent."""
    return sign_up_phone(client, name="Noah Small", age=8, mobile="+919000000100")


def test_new_child_account_starts_pending(client, child):
    response = client.get("/v1/consent/status", headers=headers(child["session_token"]))
    body = response.json()
    assert body["account_status"] == "pending_parental_consent"
    assert body["next_step"] == "parental_consent"
    assert body["consent_status"] is None


def test_path_a_parent_oauth_grants_consent(client, child):
    token = child["session_token"]
    response = client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:parent-sub-1:parent@example.com:Ruth Small",
            "parent_guardian_name": "Ruth Small",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
            "child_display_name": "Noah",
        },
        headers=headers(token),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["user"]["account_status"] == "consented"
    assert body["next_step"] == "child_privacy_notice"


def test_path_a_requires_both_attestation_boxes(client, child):
    response = client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:parent-sub-2::Parent",
            "parent_guardian_name": "Ruth Small",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": False,
        },
        headers=headers(child["session_token"]),
    )
    assert response.status_code == 400
    assert response.json()["code"] == "attestation_incomplete"


def test_parent_cannot_reuse_the_childs_own_oauth_account(client):
    """The child signs in with Google, then tries to consent as their own parent."""
    signup = client.post(
        "/v1/auth/oauth",
        json={"provider": "google", "id_token": "devtoken:kid-sub::Kid"},
        headers=headers(),
    ).json()
    token = signup["session_token"]
    client.post(
        "/v1/auth/profile", json={"name": "Kid Player", "age": 9}, headers=headers(token)
    )

    response = client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:kid-sub::Kid",
            "parent_guardian_name": "Kid Player",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
        },
        headers=headers(token),
    )
    assert response.status_code == 403
    assert response.json()["code"] == "parent_account_same_as_child"


def test_adults_cannot_run_the_consent_flow(client):
    adult = sign_up_phone(client, mobile="+919000000199")
    response = client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:someone::Someone",
            "parent_guardian_name": "Someone Else",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
        },
        headers=headers(adult["session_token"]),
    )
    assert response.status_code == 409
    assert response.json()["code"] == "consent_not_required"


# ------------------------------------------------------------------ Path B (email)
def _issue_email_token(client, db, child_token: str, email: str = "parent@example.com") -> str:
    """Issue a Path B challenge and return the raw token the parent would receive.

    Only the token hash is persisted, so a test that needs to open the parent link
    has to go through the service rather than reading it back out of the database.
    The HTTP route around it is covered separately.
    """
    from app.core.security import decode_session_token
    from app.models.user import User
    from app.services import consent as consent_service

    user_id = uuid.UUID(decode_session_token(child_token)["sub"])
    user = db.get(User, user_id)
    _record, raw_token, _sent = consent_service.issue_email_challenge(db, user, email)
    db.commit()
    return raw_token


def test_path_b_email_request_records_a_pending_record(client, child):
    response = client.post(
        "/v1/consent/email/request",
        json={"parent_email": "parent@example.com"},
        headers=headers(child["session_token"]),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["consent_status"] == "pending"
    assert body["method"] == "email_plus_confirmation"
    assert body["parent_email_masked"].endswith("@example.com")
    assert body["send_count"] == 1
    # The masked form must not leak the local part.
    assert "parent@" not in body["parent_email_masked"]


def test_path_b_resend_is_rate_limited(client, child):
    payload = {"parent_email": "parent@example.com"}
    first = client.post(
        "/v1/consent/email/request", json=payload, headers=headers(child["session_token"])
    )
    assert first.status_code == 200
    second = client.post(
        "/v1/consent/email/request", json=payload, headers=headers(child["session_token"])
    )
    assert second.status_code == 429
    assert second.json()["code"] == "resend_cooldown"


def test_path_b_web_page_grants_consent(client, child, db):
    raw_token = _issue_email_token(client, db, child["session_token"])

    page = client.get(f"/consent/verify/{raw_token}")
    assert page.status_code == 200
    assert "Noah" in page.text

    submitted = client.post(
        f"/consent/verify/{raw_token}",
        data={
            "parent_guardian_name": "Ruth Small",
            "parent_relationship": "parent",
            "consents_to_data_use": "on",
            "decision": "approve",
        },
    )
    assert submitted.status_code == 200
    assert "permission recorded" in submitted.text.lower()

    status = client.get("/v1/consent/status", headers=headers(child["session_token"])).json()
    assert status["account_status"] == "consented"
    assert status["consent_status"] == "verified"


def test_path_b_token_is_single_use(client, child, db):
    raw_token = _issue_email_token(client, db, child["session_token"])
    form = {
        "parent_guardian_name": "Ruth Small",
        "parent_relationship": "parent",
        "consents_to_data_use": "on",
        "decision": "approve",
    }
    assert client.post(f"/consent/verify/{raw_token}", data=form).status_code == 200
    replay = client.post(f"/consent/verify/{raw_token}", data=form)
    assert replay.status_code == 404
    assert "was already used" in replay.text


def test_path_b_declining_blocks_the_account(client, child, db):
    raw_token = _issue_email_token(client, db, child["session_token"])
    response = client.post(
        f"/consent/verify/{raw_token}",
        data={"parent_guardian_name": "Ruth Small", "decision": "decline"},
    )
    assert response.status_code == 200
    assert "declined" in response.text.lower()

    status = client.get("/v1/consent/status", headers=headers(child["session_token"])).json()
    assert status["account_status"] == "consent_denied"


def test_path_b_form_validation_does_not_burn_the_token(client, child, db):
    raw_token = _issue_email_token(client, db, child["session_token"])
    bad = client.post(
        f"/consent/verify/{raw_token}",
        data={"parent_guardian_name": "R", "decision": "approve"},
    )
    assert bad.status_code == 400
    assert client.get(f"/consent/verify/{raw_token}").status_code == 200


def test_unknown_token_shows_the_invalid_page(client):
    response = client.get("/consent/verify/not-a-real-token")
    assert response.status_code == 404
    assert "was already used" in response.text


def test_expired_token_is_rejected_and_flips_account_state(client, child, db):
    from app.models.consent import ParentalConsentRecord

    raw_token = _issue_email_token(client, db, child["session_token"])
    record = db.query(ParentalConsentRecord).one()
    record.expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db.commit()

    assert client.get(f"/consent/verify/{raw_token}").status_code == 404
    status = client.get("/v1/consent/status", headers=headers(child["session_token"])).json()
    assert status["account_status"] == "consent_expired"


def test_child_notice_cannot_be_acknowledged_before_consent(client, child):
    response = client.post(
        "/v1/consent/child-notice/acknowledge",
        json={"acknowledged_by": "child"},
        headers=headers(child["session_token"]),
    )
    assert response.status_code == 403
    assert response.json()["code"] == "consent_required"


def test_full_child_onboarding_reaches_the_level_map(client, child, seeded):
    token = child["session_token"]
    client.post(
        "/v1/consent/parent-oauth/complete",
        json={
            "parent_provider": "google",
            "parent_id_token": "devtoken:parent-sub-9:mum@example.com:Ruth",
            "parent_guardian_name": "Ruth Small",
            "parent_relationship": "parent",
            "is_parent_or_guardian": True,
            "consents_to_data_use": True,
        },
        headers=headers(token),
    )
    notice = client.post(
        "/v1/consent/child-notice/acknowledge",
        json={"acknowledged_by": "child"},
        headers=headers(token),
    )
    assert notice.json()["next_step"] == "privacy_acknowledgment"

    privacy = client.post(
        "/v1/auth/privacy-accept", json={"accepted": True}, headers=headers(token)
    )
    assert privacy.json()["next_step"] == "level_map"
    assert client.get("/v1/game/levels", headers=headers(token)).status_code == 200
