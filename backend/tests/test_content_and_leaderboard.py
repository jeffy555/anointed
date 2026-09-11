"""Leaderboard (B.6) and practice content sync (B.9)."""

from __future__ import annotations

import gzip
import json

import pytest

from tests.helpers import headers, onboarded_adult, play_level


@pytest.fixture()
def token(client, seeded) -> str:
    return onboarded_adult(client)


def _maybe_gunzip(body: bytes) -> bytes:
    """httpx transparently decodes Content-Encoding, but not on every version."""
    try:
        return gzip.decompress(body)
    except (OSError, gzip.BadGzipFile):
        return body


# -------------------------------------------------------------------- leaderboard
def test_leaderboard_is_empty_before_anyone_plays(client, token):
    body = client.get("/v1/leaderboard", headers=headers(token)).json()
    assert body["rows"] == []
    assert body["your_rank"]["rank"] is None
    assert body["total_entries"] == 0


def test_completing_a_level_writes_a_leaderboard_entry(client, token):
    play_level(client, token, 1)
    body = client.get("/v1/leaderboard", headers=headers(token)).json()
    assert len(body["rows"]) == 1
    assert body["rows"][0]["rank"] == 1
    assert body["rows"][0]["is_current_user"] is True
    assert body["your_rank"]["rank"] == 1


def test_only_each_players_best_entry_is_ranked(client, token, seeded):
    play_level(client, token, 1, time_ms=3000)
    play_level(client, token, 1, time_ms=5000)

    other = onboarded_adult(client, name="Rival Player", mobile="+919000000400")
    play_level(client, other, 1, time_ms=4000)

    body = client.get("/v1/leaderboard", headers=headers(token)).json()
    assert len(body["rows"]) == 2, "one row per player, not one per attempt"
    assert body["rows"][0]["score"] >= body["rows"][1]["score"]
    assert body["total_entries"] == 2


def test_failed_attempts_never_reach_the_leaderboard(client, token):
    play_level(client, token, 1, correct=False)
    body = client.get("/v1/leaderboard", headers=headers(token)).json()
    assert body["rows"] == []


def test_there_is_no_client_score_submission_endpoint(client, token):
    """design-spec §21: the client may never POST a score."""
    for path in ("/v1/leaderboard", "/v1/leaderboard/submit", "/v1/leaderboard/entries"):
        response = client.post(path, json={"score": 999_999}, headers=headers(token))
        assert response.status_code in (404, 405), path


def test_under_13_display_names_are_masked_on_the_board(client, seeded, db):
    from app.models.enums import AccountStatus
    from app.models.user import User

    from tests.helpers import sign_up_phone

    signup = sign_up_phone(client, name="Ezra Fields", age=11, mobile="+919000000401")
    kid_token = signup["session_token"]
    kid = db.query(User).filter(User.mobile == "919000000401").one()
    kid.account_status = AccountStatus.CONSENTED
    kid.child_notice_acknowledged_at = kid.created_at
    db.commit()
    client.post("/v1/auth/privacy-accept", json={"accepted": True}, headers=headers(kid_token))

    play_level(client, kid_token, 1)
    body = client.get("/v1/leaderboard", headers=headers(kid_token)).json()
    assert body["rows"][0]["display_name"] == "Ezra F."


# ------------------------------------------------------------------ content sync
def test_manifest_reports_version_zero_before_any_publish(client, token):
    body = client.get("/v1/content/manifest", headers=headers(token)).json()
    assert body["content_version"] == 0
    assert body["checksum"] is None


def test_practice_pack_is_empty_before_any_publish(client, token):
    assert client.get("/v1/content/practice-pack", headers=headers(token)).status_code == 204


def test_publishing_produces_a_downloadable_offline_pack(client, token, db):
    from app.services import content_pack

    record, report = content_pack.publish(
        db, published_by="test", change_summary="initial", threshold=10
    )
    assert report.ok, report.summary()
    db.commit()

    manifest = client.get(
        "/v1/content/manifest?local_content_version=0", headers=headers(token)
    ).json()
    assert manifest["content_version"] == record.content_version == 1
    assert manifest["checksum"] == record.checksum
    assert manifest["pack_size_bytes"] > 0

    response = client.get("/v1/content/practice-pack", headers=headers(token))
    assert response.status_code == 200
    assert response.headers["X-Content-Version"] == "1"

    pack = json.loads(_maybe_gunzip(response.content))
    assert pack["content_version"] == 1
    assert len(pack["levels"]) == 5
    assert len(pack["questions"]) == 60
    # Practice is offline and unranked, so the pack ships answers on purpose.
    assert all(question["correct_answer"] for question in pack["questions"])


def test_practice_pack_returns_204_when_the_client_is_current(client, token, db):
    from app.services import content_pack

    content_pack.publish(db, published_by="test", threshold=10)
    db.commit()

    response = client.get(
        "/v1/content/practice-pack?since_version=1", headers=headers(token)
    )
    assert response.status_code == 204


def test_publish_is_blocked_when_a_level_is_below_its_minimum(seeded, db):
    from app.services import content_pack

    record, report = content_pack.publish(db, published_by="test", threshold=50)
    assert record is None
    assert report.ok is False
    assert len(report.levels_below_minimum) == 6
    assert "below minimum" in report.summary()


def test_draft_questions_never_reach_the_pack(seeded, db):
    from app.models.content import Question
    from app.models.enums import ReviewStatus
    from app.services import content_pack

    question = db.query(Question).first()
    question.review_status = ReviewStatus.DRAFT
    db.commit()

    pack = content_pack.build_pack(db, content_version=1)
    assert str(question.id) not in {item["id"] for item in pack["questions"]}


def test_checksum_is_stable_across_builds(db, seeded):
    from app.services import content_pack

    first = content_pack.build_pack(db, content_version=3)
    second = content_pack.build_pack(db, content_version=3)
    first.pop("published_at")
    second.pop("published_at")
    assert content_pack.checksum_for(first) == content_pack.checksum_for(second)
