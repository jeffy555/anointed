"""Shared helpers for API tests."""

from __future__ import annotations

from typing import Any

HEADERS = {
    "X-Install-Id": "test-install-0001",
    "X-App-Version": "1.0.0",
    "X-Platform": "android",
    "X-Device-Type": "phone",
    "X-Session-Id": "test-session-0001",
}


def headers(token: str | None = None, **overrides: str) -> dict[str, str]:
    result = dict(HEADERS)
    result.update(overrides)
    if token:
        result["Authorization"] = f"Bearer {token}"
    return result


def sign_up_phone(client, *, name: str = "Ada Lovelace", age: int = 30, mobile: str = "+919876543210", **override_headers) -> dict[str, Any]:
    response = client.post(
        "/v1/auth/phone/signup",
        json={"mobile": mobile, "name": name, "age": age},
        headers=headers(**override_headers),
    )
    assert response.status_code == 201, response.text
    return response.json()


def accept_privacy(client, token: str) -> dict[str, Any]:
    response = client.post(
        "/v1/auth/privacy-accept", json={"accepted": True}, headers=headers(token)
    )
    assert response.status_code == 200, response.text
    return response.json()


def onboarded_adult(client, **kwargs) -> str:
    """Sign up an adult and complete onboarding; returns the session token."""
    auth = sign_up_phone(client, **kwargs)
    token = auth["session_token"]
    accept_privacy(client, token)
    return token


def play_level(client, token: str, level: int, *, correct: bool = True, time_ms: int = 3000):
    """Start an attempt and answer every question, returning the final response."""
    start = client.post(
        f"/v1/game/levels/{level}/attempts/start",
        json={"mode": "ranked"},
        headers=headers(token),
    )
    assert start.status_code == 201, start.text
    payload = start.json()
    attempt_id = payload["attempt_id"]

    last = None
    for index, question in enumerate(payload["questions"]):
        correct_index = _correct_index(question)
        selected = correct_index if correct else (correct_index + 1) % len(question["options"])
        last = client.post(
            f"/v1/game/attempts/{attempt_id}/answers",
            json={
                "question_index": index,
                "selected_option_index": selected,
                "client_time_taken_ms": time_ms,
            },
            headers=headers(token),
        )
        assert last.status_code == 200, last.text
        if last.json()["attempt_status"] != "in_progress":
            break
    return attempt_id, last.json()


def _correct_index(question) -> int:
    """Resolve the correct option by reading server truth from the database.

    The API deliberately never exposes the answer, so tests look it up the same way
    an operator would rather than weakening the endpoint to make testing easier.
    """
    import uuid

    from app.core.database import SessionLocal
    from app.models.content import Question

    with SessionLocal() as session:
        row = session.get(Question, uuid.UUID(question["question_id"]))
        return question["options"].index(row.correct_answer)
