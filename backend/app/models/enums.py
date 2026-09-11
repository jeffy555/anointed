"""Domain enumerations shared by models, schemas, and services."""

from __future__ import annotations

from enum import StrEnum


class AgeGroup(StrEnum):
    KID = "kid"
    YOUTH = "youth"
    ADULT = "adult"
    ELDER = "elder"


class AuthProvider(StrEnum):
    GOOGLE = "google"
    APPLE = "apple"
    PHONE = "phone"


class AccountStatus(StrEnum):
    """Account state machine from design-spec §11."""

    PENDING_PARENTAL_CONSENT = "pending_parental_consent"
    CONSENTED = "consented"
    CONSENT_EXPIRED = "consent_expired"
    CONSENT_DENIED = "consent_denied"
    ABANDONED_PENDING_CLEANUP = "abandoned_pending_cleanup"
    DELETED = "deleted"


class ConsentMethod(StrEnum):
    OAUTH_PARENT_ATTESTATION = "oauth_parent_attestation"
    EMAIL_PLUS_CONFIRMATION = "email_plus_confirmation"


class ConsentStatus(StrEnum):
    PENDING = "pending"
    VERIFIED = "verified"
    EXPIRED = "expired"
    DENIED = "denied"


class ParentRelationship(StrEnum):
    PARENT = "parent"
    GUARDIAN = "guardian"
    OTHER = "other"


class DifficultyTier(StrEnum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"
    EXPERT = "expert"


class Testament(StrEnum):
    OLD = "old"
    NEW = "new"


class ReviewStatus(StrEnum):
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    APPROVED = "approved"


class VariantType(StrEnum):
    """Launch baseline is text_qa + verse_clue (design-spec §18H).

    image_clue is schema- and UI-supported so images can ship in a later content
    publish without an app release; the remaining values are post-v1.
    """

    TEXT_QA = "text_qa"
    VERSE_CLUE = "verse_clue"
    IMAGE_CLUE = "image_clue"


LAUNCH_VARIANT_TYPES: tuple[VariantType, ...] = (VariantType.TEXT_QA, VariantType.VERSE_CLUE)


class AttemptMode(StrEnum):
    RANKED = "ranked"
    PRACTICE = "practice"


class AttemptStatus(StrEnum):
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    EXPIRED = "expired"
    INVALID = "invalid"
    SUSPICIOUS = "suspicious"
    ABANDONED = "abandoned"


class RejectionReason(StrEnum):
    SEQUENCE_VIOLATION = "sequence_violation"
    TIME_FLOOR = "time_floor"
    TIME_CEILING = "time_ceiling"
    EXPIRED = "expired"
    RATE_LIMIT = "rate_limit"


class Store(StrEnum):
    APP_STORE = "app_store"
    GOOGLE_PLAY = "google_play"


class UnlockStatus(StrEnum):
    PENDING = "pending"
    UNLOCKED = "unlocked"
    REFUNDED = "refunded"
    INVALID = "invalid"


class AdFormat(StrEnum):
    BANNER = "banner"
    INTERSTITIAL = "interstitial"
    REWARDED = "rewarded"


class Platform(StrEnum):
    IOS = "ios"
    ANDROID = "android"
    WEB_ADMIN = "web_admin"
    SERVER = "server"


class AdminRole(StrEnum):
    OWNER = "owner"
    EDITOR = "editor"
    REVIEWER = "reviewer"


def age_group_for(age: int) -> AgeGroup:
    """Age -> analytics/UX age group.

    Bands follow requirements.json discovery.audience (kids 6-12, youth 18-24,
    adults, elders) with 13-17 grouped into youth per meta.assumptionsMade.
    """
    if age < 13:
        return AgeGroup.KID
    if age < 25:
        return AgeGroup.YOUTH
    if age < 60:
        return AgeGroup.ADULT
    return AgeGroup.ELDER
