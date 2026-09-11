"""VPC schemas — design-spec §11."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import EmailStr, Field, field_validator

from app.models.enums import ConsentMethod, ConsentStatus, ParentRelationship
from app.schemas.common import ApiModel


class ParentOAuthConsentRequest(ApiModel):
    """M-06A + M-06B submitted together: parent OAuth token plus attestation."""

    parent_provider: Literal["google", "apple"]
    parent_id_token: str = Field(min_length=8)
    parent_guardian_name: str = Field(min_length=2, max_length=160)
    parent_relationship: ParentRelationship
    is_parent_or_guardian: bool
    consents_to_data_use: bool
    # M-06C: parent confirms/sets the child's display name.
    child_display_name: str | None = Field(default=None, max_length=120)
    child_mobile: str | None = Field(default=None, max_length=32)

    @field_validator("parent_guardian_name")
    @classmethod
    def _name(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) < 2:
            raise ValueError("Enter the parent or guardian's full name.")
        return cleaned


class ParentEmailRequest(ApiModel):
    """M-06D: parent's own email address, not the child's."""

    parent_email: EmailStr


class ConsentStatusResponse(ApiModel):
    """Polled by M-06E every 5s."""

    account_status: str
    consent_status: ConsentStatus | None
    method: ConsentMethod | None
    parent_email_masked: str | None
    expires_at: datetime | None
    can_resend_at: datetime | None
    send_count: int
    next_step: str


class WebConsentSubmission(ApiModel):
    """M-06F web page form (parent's own device)."""

    parent_guardian_name: str = Field(min_length=2, max_length=160)
    parent_relationship: ParentRelationship
    consents_to_data_use: bool = False
    decision: Literal["approve", "decline"] = "approve"


class ChildNoticeAckRequest(ApiModel):
    """M-07 acknowledgment."""

    acknowledged_by: Literal["parent", "child"] = "parent"


def mask_email(email: str | None) -> str | None:
    """``parent@example.com`` -> ``p****t@example.com`` for the M-06E wait screen."""
    if not email or "@" not in email:
        return None
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        return f"{local[0]}***@{domain}"
    return f"{local[0]}{'*' * max(len(local) - 2, 1)}{local[-1]}@{domain}"
