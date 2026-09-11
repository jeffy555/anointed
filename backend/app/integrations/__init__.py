"""Third-party integration clients. See ``base.py`` for the shared contract."""

from app.integrations.base import Integration, IntegrationError, IntegrationNotConfigured
from app.integrations.email import email_client
from app.integrations.iap import apple_iap, google_play_iap
from app.integrations.oauth import apple_oauth, google_oauth, verifier_for

__all__ = [
    "Integration",
    "IntegrationError",
    "IntegrationNotConfigured",
    "apple_iap",
    "apple_oauth",
    "email_client",
    "google_oauth",
    "google_play_iap",
    "verifier_for",
]
