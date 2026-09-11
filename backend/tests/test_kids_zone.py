"""Kids Zone progress sync.

The point of this endpoint is that it *merges*. Kids Zone stars used to live only
in the device's SharedPreferences, and sign-out wipes those — so the failure this
feature exists to prevent is a sync that lets one side's empty state overwrite the
other's earned stars. Most of what follows tests exactly that.
"""

from __future__ import annotations

from tests.helpers import headers, onboarded_adult


def sync(client, token, stops):
    response = client.post(
        "/v1/kids-zone/progress/sync",
        json={"stops": stops},
        headers=headers(token),
    )
    assert response.status_code == 200, response.text
    return response.json()["stops"]


def stop(stop_id="creation_garden", adventure_id="creation", stars=2):
    return {"stop_id": stop_id, "adventure_id": adventure_id, "stars": stars}


def test_first_sync_stores_what_the_device_sends(client):
    token = onboarded_adult(client)

    rows = sync(client, token, [stop(stars=2)])

    assert len(rows) == 1
    assert rows[0]["stop_id"] == "creation_garden"
    assert rows[0]["adventure_id"] == "creation"
    assert rows[0]["stars"] == 2


def test_empty_sync_returns_the_server_copy_rather_than_clearing_it(client):
    """The sign-out case: a freshly wiped device must not erase earned stars.

    After `clearAccountScopedState()` the device holds nothing, so the first sync
    on sign-in posts an empty list. If that were treated as "the user has no
    progress" it would delete the very record this feature was added to protect.
    """
    token = onboarded_adult(client)
    sync(client, token, [stop(stars=3)])

    rows = sync(client, token, [])

    assert len(rows) == 1
    assert rows[0]["stars"] == 3


def test_a_better_run_raises_the_star_but_a_worse_one_never_lowers_it(client):
    token = onboarded_adult(client)
    sync(client, token, [stop(stars=1)])

    assert sync(client, token, [stop(stars=3)])[0]["stars"] == 3
    # Replaying and doing badly must not cost a child a star already earned —
    # the same rule `markKidsZoneStopComplete` applies on the device.
    assert sync(client, token, [stop(stars=1)])[0]["stars"] == 3


def test_progress_from_two_devices_is_unioned(client):
    token = onboarded_adult(client)
    sync(client, token, [stop("creation_garden", "creation", 2)])

    rows = sync(client, token, [stop("moses_intro", "moses", 1)])

    assert {r["stop_id"]: r["stars"] for r in rows} == {
        "creation_garden": 2,
        "moses_intro": 1,
    }


def test_repeated_sync_is_idempotent(client):
    """No pending-write queue on the device depends on this.

    A failed sync is retried simply by sending current local state again, which
    is only safe if re-sending the same payload changes nothing.
    """
    token = onboarded_adult(client)
    first = sync(client, token, [stop(stars=2)])
    second = sync(client, token, [stop(stars=2)])

    assert first == second


def test_progress_is_scoped_to_the_account(client):
    """A shared family device is the reason sign-out wipes local progress."""
    first_token = onboarded_adult(client, mobile="+919876543210")
    sync(client, first_token, [stop(stars=3)])

    second_token = onboarded_adult(
        client, mobile="+919876500000", name="Grace Hopper"
    )

    assert sync(client, second_token, []) == []


def test_star_rating_above_the_maximum_is_refused(client):
    token = onboarded_adult(client)

    response = client.post(
        "/v1/kids-zone/progress/sync",
        json={"stops": [stop(stars=99)]},
        headers=headers(token),
    )

    assert response.status_code == 422


def test_sync_requires_a_session(client):
    response = client.post(
        "/v1/kids-zone/progress/sync", json={"stops": []}, headers=headers()
    )

    assert response.status_code == 401
