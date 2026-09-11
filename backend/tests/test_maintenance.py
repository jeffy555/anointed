"""Scheduled consent maintenance (compliance-report LB-3)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from tests.helpers import headers, sign_up_phone
from app.services.maintenance import run_consent_maintenance


def test_run_consent_maintenance_expires_stale_tokens(client, seeded, db):
    from app.models.consent import ParentalConsentRecord
    from app.models.enums import ConsentStatus

    child = sign_up_phone(client, name="Stale Token Kid", age=8, mobile="+919000000700")
    client.post(
        "/v1/consent/email/request",
        json={"parent_email": "parent@example.com"},
        headers=headers(child["session_token"]),
    )
    db.expire_all()
    record = db.query(ParentalConsentRecord).one()
    record.expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db.commit()

    expired, cleaned = run_consent_maintenance(db=db)
    assert expired >= 1
    db.expire_all()
    record = db.query(ParentalConsentRecord).one()
    assert record.status == ConsentStatus.EXPIRED


def test_run_consent_maintenance_cleans_abandoned_accounts(client, seeded, db):
    from app.models.user import User

    sign_up_phone(client, name="Abandoned Kid", age=7, mobile="+919000000800")
    db.expire_all()
    user = db.query(User).filter(User.mobile == "919000000800").one()
    user.created_at = datetime.now(timezone.utc) - timedelta(days=30)
    db.commit()

    expired, cleaned = run_consent_maintenance(db=db)
    assert cleaned >= 1
    db.expire_all()
    assert db.query(User).filter(User.mobile == "919000000800").count() == 0
