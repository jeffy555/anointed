"""Server-authoritative gameplay and anti-cheat — build order B.5 (design-spec §21)."""

from __future__ import annotations

import pytest

from tests.helpers import headers, onboarded_adult, play_level, sign_up_phone


@pytest.fixture()
def token(client, seeded) -> str:
    return onboarded_adult(client)


def test_level_map_locks_everything_past_the_next_level(client, token):
    response = client.get("/v1/game/levels", headers=headers(token))
    assert response.status_code == 200
    body = response.json()
    levels = {item["level_number"]: item for item in body["levels"]}
    assert levels[1]["locked"] is False
    assert levels[2]["locked"] is True
    assert body["current_level"] == 1
    assert body["has_unlock"] is False
    assert body["free_tier_max_level"] == 5


def test_level_map_requires_consent(client, seeded):
    kid = sign_up_phone(client, name="Kid", age=8, mobile="+919000000010")
    response = client.get("/v1/game/levels", headers=headers(kid["session_token"]))
    assert response.status_code == 403
    assert response.json()["code"] == "consent_pending"


def test_start_attempt_never_leaks_the_correct_answer(client, token):
    response = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    )
    assert response.status_code == 201
    body = response.json()
    assert len(body["questions"]) == 10
    serialised = response.text
    assert "correct_answer" not in serialised
    for question in body["questions"]:
        assert len(question["options"]) == 4
        assert "correct" not in question


def test_completing_a_level_scores_and_unlocks_the_next(client, token):
    _, final = play_level(client, token, 1)
    assert final["attempt_status"] == "completed"
    assert final["score"] > 0
    assert final["next_level_number"] == 2

    levels = {
        item["level_number"]: item
        for item in client.get("/v1/game/levels", headers=headers(token)).json()["levels"]
    }
    assert levels[1]["completed"] is True
    assert levels[2]["locked"] is False


def test_wrong_answer_fails_the_attempt_without_revealing_the_answer(client, token):
    _, final = play_level(client, token, 1, correct=False)
    assert final["attempt_status"] == "failed"
    assert final["correct"] is False
    assert final["score"] is None
    assert "correct_answer" not in final


def test_out_of_order_answer_invalidates_the_attempt(client, token):
    start = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    response = client.post(
        f"/v1/game/attempts/{start['attempt_id']}/answers",
        json={"question_index": 3, "selected_option_index": 0, "client_time_taken_ms": 3000},
        headers=headers(token),
    )
    body = response.json()
    assert body["accepted"] is False
    assert body["attempt_status"] == "invalid"
    assert body["rejection_reason"] == "sequence_violation"


def test_impossibly_fast_answer_is_flagged_suspicious(client, token):
    start = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    body = client.post(
        f"/v1/game/attempts/{start['attempt_id']}/answers",
        json={"question_index": 0, "selected_option_index": 0, "client_time_taken_ms": 50},
        headers=headers(token),
    ).json()
    assert body["attempt_status"] == "suspicious"
    assert body["rejection_reason"] == "time_floor"


def test_answer_longer_than_the_timer_is_rejected(client, token):
    start = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    body = client.post(
        f"/v1/game/attempts/{start['attempt_id']}/answers",
        json={"question_index": 0, "selected_option_index": 0, "client_time_taken_ms": 200_000},
        headers=headers(token),
    ).json()
    assert body["attempt_status"] == "invalid"
    assert body["rejection_reason"] == "time_ceiling"


def test_a_finished_attempt_rejects_further_answers(client, token):
    attempt_id, _ = play_level(client, token, 1)
    response = client.post(
        f"/v1/game/attempts/{attempt_id}/answers",
        json={"question_index": 0, "selected_option_index": 0, "client_time_taken_ms": 3000},
        headers=headers(token),
    )
    assert response.status_code == 409
    assert response.json()["code"] == "attempt_not_active"


def test_another_users_attempt_is_not_reachable(client, token, seeded):
    attempt = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    other = onboarded_adult(client, name="Other Player", mobile="+919000000055")
    response = client.get(
        f"/v1/game/attempts/{attempt['attempt_id']}", headers=headers(other)
    )
    assert response.status_code == 404


def test_starting_a_locked_paid_level_is_refused(client, token):
    """Level 6 is behind the IAP even once progression would allow it."""
    for level in range(1, 6):
        play_level(client, token, level)

    response = client.post(
        "/v1/game/levels/6/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    )
    assert response.status_code == 403
    assert response.json()["code"] == "level_locked"


def test_skipping_ahead_is_refused(client, token):
    response = client.post(
        "/v1/game/levels/3/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    )
    assert response.status_code == 403
    assert response.json()["code"] == "level_not_reached"


def test_timer_expiry_fails_the_attempt(client, token):
    start = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    response = client.post(
        f"/v1/game/attempts/{start['attempt_id']}/timer-expired",
        json={"question_index": 2},
        headers=headers(token),
    )
    assert response.status_code == 200
    assert response.json()["status"] == "failed"


def test_starting_a_new_attempt_abandons_the_previous_one(client, token):
    first = client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    ).json()
    client.post(
        "/v1/game/levels/1/attempts/start", json={"mode": "ranked"}, headers=headers(token)
    )
    state = client.get(
        f"/v1/game/attempts/{first['attempt_id']}", headers=headers(token)
    ).json()
    assert state["status"] == "abandoned"


def test_draw_honours_the_variant_mix_rules(seeded, db):
    """design-spec §18H: cap one type at 6 of 10 and include a non-text_qa."""
    import random

    from app.services.gameplay import draw_questions, live_question_pool

    pool = live_question_pool(db, 1)
    for seed in range(20):
        drawn = draw_questions(pool, 10, rng=random.Random(seed))
        assert len(drawn) == 10
        assert len({item.id for item in drawn}) == 10
        types = [str(item.variant_type) for item in drawn]
        assert max(types.count(value) for value in set(types)) <= 6
        assert any(value != "text_qa" for value in types)
