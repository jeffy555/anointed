"""Google Sign-In and Sign in with Apple identity-token verification.

Both providers issue OpenID Connect ID tokens signed with rotating RSA keys
published as a JWKS document. Verification is provider-agnostic apart from the
issuer, JWKS URL, and accepted audiences, so one client covers both.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

import httpx
import jwt
from jwt import PyJWKClient

from app.core.config import settings
from app.integrations.base import Integration, IntegrationError

GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = ("https://accounts.google.com", "accounts.google.com")

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

DEV_TOKEN_PREFIX = "devtoken:"

logger = logging.getLogger("anointed.oauth")


@dataclass(frozen=True)
class VerifiedIdentity:
    provider: str
    subject: str
    email: str | None
    name: str | None
    email_verified: bool


class _OidcVerifier(Integration):
    jwks_url: str = ""
    issuers: tuple[str, ...] = ()

    def __init__(self) -> None:
        self._jwk_client: PyJWKClient | None = None

    @property
    def audiences(self) -> list[str]:
        raise NotImplementedError

    @property
    def is_configured(self) -> bool:
        return bool(self.audiences)

    def _client(self) -> PyJWKClient:
        if self._jwk_client is None:
            self._jwk_client = PyJWKClient(self.jwks_url, cache_keys=True)
        return self._jwk_client

    def verify(self, id_token: str) -> VerifiedIdentity:
        if not self.guard():
            return self._dev_identity(id_token)
        try:
            signing_key = self._client().get_signing_key_from_jwt(id_token)
            claims = jwt.decode(
                id_token,
                signing_key.key,
                algorithms=["RS256", "ES256"],
                audience=self.audiences,
                issuer=list(self.issuers) if len(self.issuers) > 1 else self.issuers[0],
                options={"require": ["exp", "iat", "sub"]},
            )
        except (jwt.PyJWTError, httpx.HTTPError) as exc:
            if settings.environment == "development":
                _log_jwt_debug(id_token, exc)
            raise IntegrationError(
                f"{self.name} id_token verification failed: {exc}",
                safe_message="We couldn't verify that sign-in. Please try again.",
            ) from exc

        return VerifiedIdentity(
            provider=self.name,
            subject=str(claims["sub"]),
            email=claims.get("email"),
            name=claims.get("name") or claims.get("given_name"),
            email_verified=_as_bool(claims.get("email_verified")),
        )

    def _dev_identity(self, id_token: str) -> VerifiedIdentity:
        """Dev fallback: accept ``devtoken:<subject>[:<email>][:<name>]``.

        Lets the whole OAuth sign-up and VPC Path A flow be exercised end to end
        before real client IDs exist. Never reachable in production because
        ``guard()`` raises there.
        """
        if not id_token.startswith(DEV_TOKEN_PREFIX):
            raise IntegrationError(
                f"{self.name} is not configured; dev tokens must look like "
                f"'{DEV_TOKEN_PREFIX}<subject>:<email>:<name>'.",
                safe_message="We couldn't verify that sign-in. Please try again.",
            )
        parts = id_token[len(DEV_TOKEN_PREFIX) :].split(":")
        subject = parts[0] or f"dev-{int(time.time())}"
        email = parts[1] if len(parts) > 1 and parts[1] else f"{subject}@dev.local"
        name = parts[2] if len(parts) > 2 and parts[2] else None
        return VerifiedIdentity(
            provider=self.name,
            subject=f"dev|{subject}",
            email=email,
            name=name,
            email_verified=True,
        )


class GoogleOAuthClient(_OidcVerifier):
    name = "google"
    jwks_url = GOOGLE_JWKS_URL
    issuers = GOOGLE_ISSUERS

    @property
    def audiences(self) -> list[str]:
        return settings.google_client_id_list


class AppleOAuthClient(_OidcVerifier):
    name = "apple"
    jwks_url = APPLE_JWKS_URL
    issuers = (APPLE_ISSUER,)

    @property
    def audiences(self) -> list[str]:
        return settings.apple_audience_list

    @property
    def is_configured(self) -> bool:
        # apple_bundle_ids defaults to the app's bundle id, which is enough to
        # verify a native Sign in with Apple token; no client secret is needed.
        return bool(self.audiences) and bool(settings.apple_bundle_ids.strip())


def _log_jwt_debug(id_token: str, exc: Exception) -> None:
    """Log unverified JWT claims in development to speed up OAuth debugging."""
    try:
        claims = jwt.decode(
            id_token,
            options={
                "verify_signature": False,
                "verify_aud": False,
                "verify_exp": False,
                "verify_iat": False,
                "verify_iss": False,
            },
        )
        logger.warning(
            "OAuth JWT verify failed (%s). Unverified claims: aud=%s azp=%s iss=%s sub=%s",
            exc,
            claims.get("aud"),
            claims.get("azp"),
            claims.get("iss"),
            claims.get("sub"),
        )
    except jwt.PyJWTError:
        logger.warning("OAuth JWT verify failed (%s). Token is not decodable JWT.", exc)


def _as_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    return False


google_oauth = GoogleOAuthClient()
apple_oauth = AppleOAuthClient()


def verifier_for(provider: str) -> _OidcVerifier:
    if provider == "google":
        return google_oauth
    if provider == "apple":
        return apple_oauth
    raise IntegrationError(
        f"Unsupported OAuth provider '{provider}'.",
        safe_message="That sign-in method isn't supported.",
    )
