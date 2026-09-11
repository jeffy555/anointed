"""Transactional email client for VPC Path B parent verification links.

Provider-agnostic on purpose: requirements.json names "SendGrid/Resend/SES" without
choosing one, so this speaks each provider's plain REST API rather than pulling in a
vendor SDK. Swapping providers is an ``EMAIL_PROVIDER`` + key change.
"""

from __future__ import annotations

import httpx

from app.core.config import settings
from app.integrations.base import Integration, IntegrationError, logger

_PROVIDER_ENDPOINTS = {
    "sendgrid": "https://api.sendgrid.com/v3/mail/send",
    "resend": "https://api.resend.com/emails",
    "ses": "",  # SES requires a region-specific host; supply EMAIL_API_BASE.
}


class EmailClient(Integration):
    name = "transactional_email"

    @property
    def is_configured(self) -> bool:
        return settings.email_provider != "none" and bool(settings.email_api_key.strip())

    def _endpoint(self) -> str:
        if settings.email_api_base.strip():
            return settings.email_api_base.strip()
        endpoint = _PROVIDER_ENDPOINTS.get(settings.email_provider, "")
        if not endpoint:
            raise IntegrationError(
                f"EMAIL_PROVIDER='{settings.email_provider}' needs EMAIL_API_BASE set explicitly.",
                safe_message="We couldn't send that email right now.",
            )
        return endpoint

    def send(self, *, to: str, subject: str, html: str, text: str) -> bool:
        """Send one message. Returns True if the provider accepted it.

        Dev fallback logs the full message (including the consent link) so Path B
        can be completed locally without an email account.
        """
        if not self.guard():
            logger.warning(
                "[dev-fallback] transactional email not sent. to=%s subject=%s\n%s",
                to,
                subject,
                text,
            )
            return False

        payload, headers = self._build_request(to=to, subject=subject, html=html, text=text)
        try:
            response = httpx.post(self._endpoint(), json=payload, headers=headers, timeout=15.0)
        except httpx.HTTPError as exc:
            raise IntegrationError(
                f"email provider request failed: {exc}",
                safe_message="We couldn't send that email. Please try again.",
            ) from exc

        if response.status_code >= 400:
            raise IntegrationError(
                f"email provider returned {response.status_code}",
                safe_message="We couldn't send that email. Please try again.",
            )
        return True

    def _build_request(
        self, *, to: str, subject: str, html: str, text: str
    ) -> tuple[dict, dict[str, str]]:
        headers = {
            "Authorization": f"Bearer {settings.email_api_key}",
            "Content-Type": "application/json",
        }
        sender = settings.consent_email_from
        if settings.email_provider == "sendgrid":
            payload = {
                "personalizations": [{"to": [{"email": to}]}],
                "from": {"email": sender, "name": settings.consent_email_from_name},
                "subject": subject,
                "content": [
                    {"type": "text/plain", "value": text},
                    {"type": "text/html", "value": html},
                ],
            }
        else:
            # Resend's shape; SES v2 SendEmail via EMAIL_API_BASE accepts a similar body.
            payload = {
                "from": f"{settings.consent_email_from_name} <{sender}>",
                "to": [to],
                "subject": subject,
                "html": html,
                "text": text,
            }
        return payload, headers


email_client = EmailClient()
