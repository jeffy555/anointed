"""Apple App Store and Google Play receipt validation for the level-unlock SKU.

Both clients return the same ``ReceiptValidation`` shape so the IAP router does not
branch on store beyond picking a client.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone

import httpx
import jwt

from app.core.config import settings
from app.integrations.base import Integration, IntegrationError, logger
from app.models.enums import Store

APPLE_VERIFY_PROD = "https://buy.itunes.apple.com/verifyReceipt"
APPLE_VERIFY_SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt"
APPLE_SANDBOX_RECEIPT_STATUS = 21007

GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

DEV_RECEIPT_PREFIX = "devreceipt:"


@dataclass
class ReceiptValidation:
    valid: bool
    store: Store
    product_id: str
    transaction_id: str
    original_transaction_id: str | None = None
    purchased_at: datetime | None = None
    validated_by_provider: bool = False
    raw: dict = field(default_factory=dict)
    reason: str | None = None


def _dev_validation(store: Store, receipt: str) -> ReceiptValidation:
    """Dev fallback: accept ``devreceipt:<transaction_id>`` as a successful purchase.

    Makes the entire purchase -> unlock -> levels 6-100 path testable before real
    store credentials and a registered SKU exist. Unreachable in production.
    """
    if not receipt.startswith(DEV_RECEIPT_PREFIX):
        return ReceiptValidation(
            valid=False,
            store=store,
            product_id=settings.iap_product_id,
            transaction_id="",
            reason="dev_receipt_expected",
        )
    transaction_id = receipt[len(DEV_RECEIPT_PREFIX) :].strip() or f"dev-{int(time.time())}"
    logger.warning(
        "[dev-fallback] accepting unverified %s receipt as valid: %s", store, transaction_id
    )
    return ReceiptValidation(
        valid=True,
        store=store,
        product_id=settings.iap_product_id,
        transaction_id=transaction_id,
        original_transaction_id=transaction_id,
        purchased_at=datetime.now(timezone.utc),
        validated_by_provider=False,
        raw={"dev_fallback": True},
    )


class AppleIapClient(Integration):
    name = "apple_iap"

    @property
    def is_configured(self) -> bool:
        return bool(settings.apple_iap_shared_secret.strip())

    def validate(self, receipt_data: str) -> ReceiptValidation:
        if not self.guard():
            return _dev_validation(Store.APP_STORE, receipt_data)

        body = {
            "receipt-data": receipt_data,
            "password": settings.apple_iap_shared_secret,
            "exclude-old-transactions": True,
        }
        payload = self._post(
            APPLE_VERIFY_SANDBOX if settings.apple_iap_use_sandbox else APPLE_VERIFY_PROD, body
        )
        # Apple returns 21007 when a sandbox receipt hits the production endpoint.
        # Retrying against sandbox is the documented handling, and it is what makes
        # TestFlight builds work against a production API.
        if payload.get("status") == APPLE_SANDBOX_RECEIPT_STATUS:
            payload = self._post(APPLE_VERIFY_SANDBOX, body)

        status = payload.get("status")
        if status != 0:
            return ReceiptValidation(
                valid=False,
                store=Store.APP_STORE,
                product_id=settings.iap_product_id,
                transaction_id="",
                raw=payload,
                reason=f"apple_status_{status}",
            )

        purchase = self._find_purchase(payload)
        if purchase is None:
            return ReceiptValidation(
                valid=False,
                store=Store.APP_STORE,
                product_id=settings.iap_product_id,
                transaction_id="",
                raw=payload,
                reason="product_not_in_receipt",
            )

        if purchase.get("cancellation_date") or purchase.get("cancellation_date_ms"):
            return ReceiptValidation(
                valid=False,
                store=Store.APP_STORE,
                product_id=str(purchase.get("product_id")),
                transaction_id=str(purchase.get("transaction_id") or ""),
                raw=payload,
                reason="purchase_revoked",
            )

        # App Store Server Notifications V2 can drive async revocation; this check
        # catches refunds on the next client restore/validate call.
        return ReceiptValidation(
            valid=True,
            store=Store.APP_STORE,
            product_id=str(purchase.get("product_id")),
            transaction_id=str(purchase.get("transaction_id")),
            original_transaction_id=str(
                purchase.get("original_transaction_id") or purchase.get("transaction_id")
            ),
            purchased_at=_apple_timestamp(purchase.get("purchase_date_ms")),
            validated_by_provider=True,
            raw=payload,
        )

    def _post(self, url: str, body: dict) -> dict:
        try:
            response = httpx.post(url, json=body, timeout=20.0)
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise IntegrationError(
                f"Apple verifyReceipt call failed: {exc}",
                safe_message="We couldn't confirm that purchase. Please try again.",
            ) from exc

    @staticmethod
    def _find_purchase(payload: dict) -> dict | None:
        receipts = payload.get("latest_receipt_info") or []
        if not receipts:
            receipts = (payload.get("receipt") or {}).get("in_app") or []
        for item in receipts:
            if item.get("product_id") == settings.iap_product_id:
                return item
        return receipts[0] if receipts else None


class GooglePlayIapClient(Integration):
    name = "google_play_iap"

    def __init__(self) -> None:
        self._token: str | None = None
        self._token_expires_at: float = 0.0

    @property
    def is_configured(self) -> bool:
        return bool(settings.google_play_service_account_json.strip())

    def validate(self, purchase_token: str, product_id: str | None = None) -> ReceiptValidation:
        if not self.guard():
            return _dev_validation(Store.GOOGLE_PLAY, purchase_token)

        product = product_id or settings.iap_product_id
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            f"{settings.google_play_package_name}/purchases/products/{product}/tokens/"
            f"{purchase_token}"
        )
        try:
            response = httpx.get(
                url,
                headers={"Authorization": f"Bearer {self._access_token()}"},
                timeout=20.0,
            )
        except httpx.HTTPError as exc:
            raise IntegrationError(
                f"Google Play purchases API call failed: {exc}",
                safe_message="We couldn't confirm that purchase. Please try again.",
            ) from exc

        if response.status_code >= 400:
            return ReceiptValidation(
                valid=False,
                store=Store.GOOGLE_PLAY,
                product_id=product,
                transaction_id="",
                reason=f"google_http_{response.status_code}",
                raw={"status": response.status_code},
            )

        payload = response.json()
        # purchaseState: 0 purchased, 1 cancelled, 2 pending.
        purchased = payload.get("purchaseState") == 0
        if not purchased:
            return ReceiptValidation(
                valid=False,
                store=Store.GOOGLE_PLAY,
                product_id=product,
                transaction_id=str(payload.get("orderId") or purchase_token),
                raw=payload,
                reason=f"purchase_state_{payload.get('purchaseState')}",
            )

        return ReceiptValidation(
            valid=True,
            store=Store.GOOGLE_PLAY,
            product_id=product,
            transaction_id=str(payload.get("orderId") or purchase_token),
            original_transaction_id=str(payload.get("orderId") or purchase_token),
            purchased_at=_google_timestamp(payload.get("purchaseTimeMillis")),
            validated_by_provider=True,
            raw=payload,
        )

    def acknowledge(self, purchase_token: str, product_id: str | None = None) -> None:
        """Acknowledge a product purchase within Play's 3-day window."""
        if not self.guard():
            return

        product = product_id or settings.iap_product_id
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            f"{settings.google_play_package_name}/purchases/products/{product}/tokens/"
            f"{purchase_token}:acknowledge"
        )
        try:
            response = httpx.post(
                url,
                headers={"Authorization": f"Bearer {self._access_token()}"},
                json={"developerPayload": "anointed"},
                timeout=20.0,
            )
            response.raise_for_status()
        except httpx.HTTPError as exc:
            raise IntegrationError(
                f"Google Play acknowledge failed: {exc}",
                safe_message="We couldn't confirm that purchase. Please try again.",
            ) from exc

    def _access_token(self) -> str:
        """Service-account JWT bearer exchange for an androidpublisher access token."""
        if self._token and time.time() < self._token_expires_at - 60:
            return self._token

        try:
            credentials = json.loads(settings.google_play_service_account_json)
        except json.JSONDecodeError as exc:
            raise IntegrationError(
                "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not valid JSON.",
                safe_message="We couldn't confirm that purchase. Please try again.",
            ) from exc

        now = int(time.time())
        assertion = jwt.encode(
            {
                "iss": credentials["client_email"],
                "scope": GOOGLE_PUBLISHER_SCOPE,
                "aud": GOOGLE_TOKEN_URL,
                "iat": now,
                "exp": now + 3600,
            },
            credentials["private_key"],
            algorithm="RS256",
        )
        try:
            response = httpx.post(
                GOOGLE_TOKEN_URL,
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    "assertion": assertion,
                },
                timeout=20.0,
            )
            response.raise_for_status()
            payload = response.json()
        except (httpx.HTTPError, KeyError, ValueError) as exc:
            raise IntegrationError(
                f"Google service-account token exchange failed: {exc}",
                safe_message="We couldn't confirm that purchase. Please try again.",
            ) from exc

        self._token = payload["access_token"]
        self._token_expires_at = time.time() + int(payload.get("expires_in", 3600))
        return self._token


def _apple_timestamp(value: object) -> datetime | None:
    try:
        return datetime.fromtimestamp(int(str(value)) / 1000, tz=timezone.utc)
    except (TypeError, ValueError):
        return None


def _google_timestamp(value: object) -> datetime | None:
    return _apple_timestamp(value)


apple_iap = AppleIapClient()
google_play_iap = GooglePlayIapClient()
