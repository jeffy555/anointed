"""Auth — build order B.1 (Google, Apple, phone; no SMS OTP)."""

from __future__ import annotations

from tests.helpers import accept_privacy, headers, sign_up_phone


def test_phone_signup_creates_account_and_routes_to_privacy(client):
    body = sign_up_phone(client)
    assert body["is_new_account"] is True
    assert body["next_step"] == "privacy_acknowledgment"
    assert body["user"]["age_group"] == "adult"
    assert body["user"]["is_under_13"] is False
    assert body["session_token"]


def test_phone_signup_under_13_routes_to_parental_consent(client):
    body = sign_up_phone(client, name="Sam Young", age=9, mobile="+919000000001")
    assert body["next_step"] == "parental_consent"
    assert body["user"]["account_status"] == "pending_parental_consent"
    assert body["user"]["is_under_13"] is True


def test_privacy_acceptance_completes_onboarding(client):
    token = sign_up_phone(client)["session_token"]
    body = accept_privacy(client, token)
    assert body["next_step"] == "level_map"
    assert body["user"]["privacy_accepted"] is True


def test_duplicate_phone_signup_is_rejected(client):
    sign_up_phone(client)
    response = client.post(
        "/v1/auth/phone/signup",
        json={"mobile": "+919876543210", "name": "Ada Lovelace", "age": 30},
        headers=headers(),
    )
    assert response.status_code == 409
    assert response.json()["code"] == "account_exists"


def test_phone_signin_matches_on_mobile_and_name(client):
    sign_up_phone(client)
    response = client.post(
        "/v1/auth/phone/signin",
        json={"mobile": "919876543210", "name": "  ada lovelace "},
        headers=headers(),
    )
    assert response.status_code == 200, response.text
    assert response.json()["is_new_account"] is False


def test_phone_signin_unknown_account_returns_not_found(client):
    response = client.post(
        "/v1/auth/phone/signin",
        json={"mobile": "+910000000000", "name": "Nobody"},
        headers=headers(),
    )
    assert response.status_code == 404
    assert response.json()["code"] == "account_not_found"


def test_phone_signup_is_rate_limited_per_install(client):
    """design-spec §21: max 5 phone accounts per install per day."""
    for index in range(5):
        response = client.post(
            "/v1/auth/phone/signup",
            json={"mobile": f"+91900000{index:04d}", "name": f"User {index}", "age": 20},
            headers=headers(),
        )
        assert response.status_code == 201, response.text

    blocked = client.post(
        "/v1/auth/phone/signup",
        json={"mobile": "+919000009999", "name": "User Six", "age": 20},
        headers=headers(),
    )
    assert blocked.status_code == 429
    assert blocked.json()["code"] == "signup_rate_limited"
    assert "Retry-After" in blocked.headers


def test_oauth_signup_dev_fallback_creates_account(client):
    """With no client IDs configured, the dev token path stands in for real OAuth."""
    response = client.post(
        "/v1/auth/oauth",
        json={
            "provider": "google",
            "id_token": "devtoken:google-sub-1:kid@example.com:Grace Hopper",
        },
        headers=headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["is_new_account"] is True
    # OAuth never supplies age, so the client must collect it before age routing.
    assert body["next_step"] == "profile_completion"


def test_oauth_signin_restores_the_same_account(client):
    first = client.post(
        "/v1/auth/oauth",
        json={"provider": "google", "id_token": "devtoken:sub-restore::Grace"},
        headers=headers(),
    ).json()
    client.post(
        "/v1/auth/profile",
        json={"name": "Grace Hopper", "age": 34},
        headers=headers(first["session_token"]),
    )
    second = client.post(
        "/v1/auth/oauth",
        json={"provider": "google", "id_token": "devtoken:sub-restore::Grace"},
        headers=headers(),
    ).json()
    assert second["is_new_account"] is False
    assert second["user"]["id"] == first["user"]["id"]
    assert second["next_step"] == "privacy_acknowledgment"


def test_profile_completion_applies_age_routing(client):
    token = client.post(
        "/v1/auth/oauth",
        json={"provider": "apple", "id_token": "devtoken:apple-kid::Kid"},
        headers=headers(),
    ).json()["session_token"]

    response = client.post(
        "/v1/auth/profile", json={"name": "Kid Player", "age": 8}, headers=headers(token)
    )
    assert response.status_code == 200
    assert response.json()["next_step"] == "parental_consent"


def test_session_requires_a_token(client):
    assert client.get("/v1/auth/session").status_code == 401


def test_under_13_cannot_accept_privacy_before_consent(client):
    token = sign_up_phone(client, name="Kid", age=7, mobile="+919000000002")["session_token"]
    response = client.post(
        "/v1/auth/privacy-accept", json={"accepted": True}, headers=headers(token)
    )
    assert response.status_code == 400
    assert response.json()["code"] == "consent_required"
