"""Auth request/response schemas — Google, Apple, and phone (no OTP)."""

from __future__ import annotations

from typing import Literal

from pydantic import Field, field_validator

from app.models.enums import AccountStatus, AgeGroup, AuthProvider
from app.schemas.common import ApiModel

MIN_AGE = 4
MAX_AGE = 120


def _clean_mobile(value: str) -> str:
    """Normalise to digits only, discarding '+', spaces, and punctuation.

    Phone sign-in matches on this value and there is no OTP to fall back on, so
    sign-up and sign-in must normalise identically. Dropping the '+' rather than
    preserving it is deliberate: otherwise someone who typed '+91…' at sign-up and
    '91…' at sign-in would be locked out of their own account with no recovery path.
    """
    digits = "".join(ch for ch in value if ch.isdigit())
    if not 6 <= len(digits) <= 15:
        raise ValueError("Enter a valid mobile number.")
    return digits


class OAuthSignInRequest(ApiModel):
    provider: Literal["google", "apple"]
    id_token: str = Field(min_length=8)
    # Apple only returns the display name on the very first authorisation, so the
    # client forwards it when present rather than relying on the token.
    name: str | None = Field(default=None, max_length=120)
    age: int | None = Field(default=None, ge=MIN_AGE, le=MAX_AGE)


class PhoneSignUpRequest(ApiModel):
    mobile: str
    name: str = Field(min_length=1, max_length=120)
    age: int = Field(ge=MIN_AGE, le=MAX_AGE)

    @field_validator("mobile")
    @classmethod
    def _mobile(cls, value: str) -> str:
        return _clean_mobile(value)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Enter a name.")
        return cleaned


class PhoneSignInRequest(ApiModel):
    mobile: str
    name: str = Field(min_length=1, max_length=120)

    @field_validator("mobile")
    @classmethod
    def _mobile(cls, value: str) -> str:
        return _clean_mobile(value)


class ProfileCompletionRequest(ApiModel):
    """Age capture for the OAuth path, where the provider never supplies age."""

    name: str = Field(min_length=1, max_length=120)
    age: int = Field(ge=MIN_AGE, le=MAX_AGE)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Enter a name.")
        return cleaned


class PrivacyAcceptRequest(ApiModel):
    accepted: bool = True


class SessionUser(ApiModel):
    id: str
    name: str | None
    age: int | None
    age_group: AgeGroup | None
    is_under_13: bool
    account_status: AccountStatus
    primary_auth_provider: AuthProvider | None
    privacy_accepted: bool
    child_notice_acknowledged: bool
    notifications_opt_in: bool
    has_unlock: bool
    highest_level_completed: int
    levels_completed_count: int


class AuthResponse(ApiModel):
    session_token: str
    user: SessionUser
    # Which onboarding screen the client should route to. The server owns this so
    # the routing rules in design-spec §3 live in exactly one place.
    next_step: Literal[
        "profile_completion",
        "parental_consent",
        "child_privacy_notice",
        "privacy_acknowledgment",
        "level_map",
    ]
    is_new_account: bool


class SessionResponse(ApiModel):
    user: SessionUser
    next_step: str
