"""Shared contract for every third-party integration client.

The pattern each client follows:

* ``is_configured`` reads the relevant settings and is the *only* signal callers
  use to choose between the real provider and the dev fallback. Callers never
  read environment variables themselves.
* When configured, call the real provider.
* When not configured and the environment is non-production, use a documented dev
  fallback (log the email link, accept a clearly-marked sandbox receipt) so the
  surrounding feature is fully exercisable today.
* When not configured and the environment *is* production, raise
  ``IntegrationNotConfigured``. A misconfigured production deploy must fail
  loudly rather than quietly printing consent links to stdout.
* Provider failures surface as ``IntegrationError`` so routers can return a
  user-safe message without leaking provider internals.
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod

from app.core.config import settings

logger = logging.getLogger("anointed.integrations")


class IntegrationError(Exception):
    """A provider call failed. ``safe_message`` is what an end user may see."""

    def __init__(self, message: str, *, safe_message: str | None = None) -> None:
        super().__init__(message)
        self.safe_message = safe_message or "That service is unavailable right now."


class IntegrationNotConfigured(IntegrationError):
    """Credentials are missing in an environment that requires them."""

    def __init__(self, name: str) -> None:
        super().__init__(
            f"Integration '{name}' has no credentials configured and the environment is "
            f"'{settings.environment}'. Set the required variables from .env.example.",
            safe_message="That service is not available right now.",
        )


class Integration(ABC):
    """Base class holding the configured/fallback decision."""

    name: str = "integration"

    @property
    @abstractmethod
    def is_configured(self) -> bool:
        """True when every credential this client needs is present."""

    def guard(self) -> bool:
        """Return True to proceed with the real provider, False to use the dev fallback.

        Raises in production when unconfigured.
        """
        if self.is_configured:
            return True
        if settings.is_production:
            raise IntegrationNotConfigured(self.name)
        logger.warning(
            "[dev-fallback] %s is not configured; using the local fallback path. "
            "This path is disabled in production.",
            self.name,
        )
        return False
