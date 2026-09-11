"""SQLAlchemy models. Importing this package registers every table on ``Base.metadata``."""

from app.models.analytics import AdminUser, AnalyticsEvent, AuditLog
from app.models.commerce import AdImpressionLog, PurchaseRecord
from app.models.consent import ParentalConsentRecord
from app.models.content import BibleCharacter, ContentPublishRecord, Level, Question
from app.models.gameplay import LeaderboardEntry, LevelAttempt, UserPerformanceSummary
from app.models.kids_zone import KidsZoneStopCompletion
from app.models.user import (
    AuthIdentity,
    LevelCompletion,
    RateLimitCounter,
    SupportRequest,
    User,
    UserProgress,
)

__all__ = [
    "AdImpressionLog",
    "AdminUser",
    "AnalyticsEvent",
    "AuditLog",
    "AuthIdentity",
    "BibleCharacter",
    "ContentPublishRecord",
    "KidsZoneStopCompletion",
    "LeaderboardEntry",
    "Level",
    "LevelAttempt",
    "LevelCompletion",
    "ParentalConsentRecord",
    "PurchaseRecord",
    "Question",
    "RateLimitCounter",
    "SupportRequest",
    "User",
    "UserPerformanceSummary",
    "UserProgress",
]
