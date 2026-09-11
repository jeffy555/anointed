"""Application settings.

Every third-party credential is optional at the type level so the app boots in
local development without any of them. Each integration client decides whether it
is configured and, when it is not, either uses a dev fallback (non-production) or
raises at call time (production). See ``app.integrations.base``.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ---------------------------------------------------------------- runtime
    environment: Literal["development", "test", "staging", "production"] = "development"
    api_base_url: str = "http://localhost:8000"
    web_base_url: str = "http://localhost:8000"
    log_level: str = "INFO"

    # --------------------------------------------------------------- database
    # NeonDB connection string. Neon requires sslmode=require.
    database_url: str = "postgresql+psycopg://anointed:anointed@localhost:5432/anointed"

    # ------------------------------------------------------------------- auth
    jwt_secret: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    session_token_ttl_days: int = 3650  # persistent session; no inactivity timeout

    google_oauth_client_ids: str = ""  # comma-separated: android, ios, web
    apple_bundle_ids: str = "com.anointed.app"
    apple_service_ids: str = ""

    # ------------------------------------------------------------------- VPC
    consent_email_from: str = "no-reply@anointed.app"
    consent_email_from_name: str = "Anointed"
    consent_token_ttl_hours: int = 72
    consent_pending_cleanup_days: int = 14
    consent_resend_cooldown_seconds: int = 60
    consent_max_sends_per_day: int = 5
    consent_policy_version: str = "2026-09-01"

    email_provider: Literal["sendgrid", "resend", "ses", "none"] = "none"
    email_api_key: str = ""
    email_api_base: str = ""

    # ------------------------------------------------------------------- IAP
    iap_product_id: str = "com.anointed.app.unlock_levels"
    iap_price_display: str = "\u20b949"
    iap_price_amount_minor: int = 4900
    iap_price_currency: str = "INR"

    apple_iap_shared_secret: str = ""
    apple_iap_use_sandbox: bool = False
    google_play_package_name: str = "com.anointed.app"
    google_play_service_account_json: str = ""

    # ------------------------------------------------------------------- ads
    admob_app_id_android: str = ""
    admob_app_id_ios: str = ""
    admob_interstitial_unit_android: str = ""
    admob_interstitial_unit_ios: str = ""

    # Set true only after completing docs/admob_coppa_checklist.md (C-11).
    admob_production_ack: bool = False

    # ---------------------------------------------------------------- content
    free_tier_max_level: int = 5
    total_levels: int = 100
    questions_per_attempt: int = 10
    beta_min_questions_per_level: int = 15
    launch_min_questions_per_level: int = 20

    # -------------------------------------------------------------- anticheat
    answer_time_floor_ms: int = 800
    answer_time_ceiling_grace_ms: int = 2000
    attempt_total_grace_seconds: int = 30
    attempt_starts_per_user_per_hour: int = 20
    attempt_starts_per_install_per_hour: int = 20

    # ----------------------------------------------------- signup rate limits
    phone_signups_per_install_per_day: int = 5
    phone_signups_per_ip_per_day: int = 20

    # ------------------------------------------------------------------- ads/gameplay policy
    ad_min_level: int = 4  # levels 1-3 are ad-free (onboarding grace)
    ad_every_nth_level: int = 3
    ad_max_per_session: int = 2
    child_age_threshold: int = 13

    # ---------------------------------------------------------- adaptive difficulty
    adaptive_enabled: bool = True
    adaptive_min_timer_kid: int = 20
    adaptive_min_timer_elder: int = 20
    adaptive_min_timer_default: int = 15
    adaptive_max_timer: int = 90
    adaptive_timer_step_seconds: int = 10
    adaptive_timer_bonus_cap: int = 30
    adaptive_elder_failed_bonus_seconds: int = 20
    adaptive_elder_failed_attempts: int = 3
    adaptive_struggling_pass_rate: float = 0.34
    adaptive_struggling_timer_utilization: float = 0.12
    adaptive_excelling_first_try_rate: float = 0.5
    adaptive_excelling_timer_utilization: float = 0.55
    adaptive_excelling_pass_rate: float = 0.5

    # ----------------------------------------------------------------- admin
    admin_session_secret: str = "dev-only-admin-session-secret-change-me"
    admin_bootstrap_email: str = ""
    admin_bootstrap_password: str = ""

    # ---------------------------------------------------------- force upgrade
    minimum_app_version: str = "1.0.0"
    current_store_version: str = "1.0.0"
    minimum_app_build: int = 1
    app_store_url: str = "https://apps.apple.com/app/id0000000000"
    play_store_url: str = "https://play.google.com/store/apps/details?id=com.anointed.app"
    force_upgrade_release_notes: str = ""

    # ---------------------------------------------------------------- support
    support_email: str = "support@anointed.app"

    # ------------------------------------------------------------------ links
    privacy_policy_url: str = "https://anointed.app/privacy"
    terms_of_service_url: str = "https://anointed.app/terms"

    cors_origins: str = "*"

    # How often the in-process maintenance loop runs (consent token expiry + pending cleanup).
    maintenance_interval_seconds: int = 3600

    @field_validator("database_url")
    @classmethod
    def _normalise_driver(cls, value: str) -> str:
        # Neon and most hosts hand out `postgresql://` or `postgres://` URLs;
        # SQLAlchemy needs the psycopg3 driver named explicitly.
        if value.startswith("postgres://"):
            value = value.replace("postgres://", "postgresql+psycopg://", 1)
        elif value.startswith("postgresql://"):
            value = value.replace("postgresql://", "postgresql+psycopg://", 1)
        return value

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def google_client_id_list(self) -> list[str]:
        return [item.strip() for item in self.google_oauth_client_ids.split(",") if item.strip()]

    @property
    def apple_audience_list(self) -> list[str]:
        raw = f"{self.apple_bundle_ids},{self.apple_service_ids}"
        return [item.strip() for item in raw.split(",") if item.strip()]

    @property
    def cors_origin_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]

    @property
    def cors_allows_wildcard(self) -> bool:
        return "*" in self.cors_origin_list


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
