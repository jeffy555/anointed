"""M-06F — the parent-facing web confirmation page for VPC Path B.

Served from the FastAPI app (not the mobile client) because the parent opens it on
their own device from the emailed link.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.core.config import settings
from app.core.deps import DbSession
from app.models.enums import ConsentMethod, ParentRelationship
from app.services import analytics, consent as consent_service

TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "web" / "templates"
templates = Jinja2Templates(directory=str(TEMPLATE_DIR))

router = APIRouter(prefix="/consent", tags=["consent-web"], include_in_schema=False)


def _result(
    request: Request,
    *,
    status_code: int,
    heading: str,
    message: str,
    icon: str,
    banner_class: str,
    child_name: str = "Your child",
    show_return_hint: bool = False,
) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="consent_result.html",
        status_code=status_code,
        context={
            "heading": heading,
            "message": message,
            "icon": icon,
            "banner_class": banner_class,
            "child_name": child_name,
            "show_return_hint": show_return_hint,
            "support_email": settings.support_email,
        },
    )


def _invalid_link(request: Request) -> HTMLResponse:
    return _result(
        request,
        status_code=404,
        heading="This link isn't valid",
        message=(
            "This permission link has expired, was already used, or isn't recognised. "
            "Ask your child to tap \u201cResend email\u201d in the app to get a new one."
        ),
        icon="\u26a0\ufe0f",
        banner_class="error",
    )


def _expires_label(expires_at: datetime | None) -> str:
    if expires_at is None:
        return f"in {settings.consent_token_ttl_hours} hours"
    aware = expires_at if expires_at.tzinfo else expires_at.replace(tzinfo=timezone.utc)
    hours = max(int((aware - datetime.now(timezone.utc)).total_seconds() // 3600), 0)
    return f"in about {hours} hour{'s' if hours != 1 else ''}"


@router.get("/verify/{token}", response_class=HTMLResponse)
def show_consent_page(token: str, request: Request, db: DbSession) -> HTMLResponse:
    resolved = consent_service.resolve_token(db, token)
    if resolved is None:
        return _invalid_link(request)

    record, child = resolved
    child_name = (child.name or "your child").split()[0]
    return templates.TemplateResponse(
        request=request,
        name="consent_verify.html",
        context={
            "child_name": child_name,
            "form_action": f"/consent/verify/{token}",
            "prefill_name": record.parent_guardian_name,
            "policy_version": settings.consent_policy_version,
            "privacy_policy_url": settings.privacy_policy_url,
            "support_email": settings.support_email,
            "expires_label": _expires_label(record.expires_at),
            "error": None,
        },
    )


@router.post("/verify/{token}", response_class=HTMLResponse)
def submit_consent_page(
    token: str,
    request: Request,
    db: DbSession,
    parent_guardian_name: str = Form(default=""),
    parent_relationship: str = Form(default="parent"),
    consents_to_data_use: str | None = Form(default=None),
    decision: str = Form(default="approve"),
) -> HTMLResponse:
    resolved = consent_service.resolve_token(db, token)
    if resolved is None:
        return _invalid_link(request)

    record, child = resolved
    child_name = (child.name or "your child").split()[0]

    if decision == "decline":
        consent_service.deny_consent(db, child, record)
        analytics.track(
            db,
            "vpc_consent_denied",
            user=child,
            properties={"vpc_path": str(ConsentMethod.EMAIL_PLUS_CONFIRMATION)},
        )
        return _result(
            request,
            status_code=200,
            heading="Permission declined",
            message=(
                "Thank you for letting us know. This account will not be activated, and "
                "we will remove the information we collected during sign-up."
            ),
            icon="\U0001f6d1",
            banner_class="error",
            child_name=child_name,
        )

    cleaned_name = parent_guardian_name.strip()
    if len(cleaned_name) < 2 or consents_to_data_use is None:
        # Re-render the form with the record still pending so the parent can retry;
        # the token is deliberately not burned on a validation failure.
        return templates.TemplateResponse(
            request=request,
            name="consent_verify.html",
            status_code=400,
            context={
                "child_name": child_name,
                "form_action": f"/consent/verify/{token}",
                "prefill_name": cleaned_name or record.parent_guardian_name,
                "policy_version": settings.consent_policy_version,
                "privacy_policy_url": settings.privacy_policy_url,
                "support_email": settings.support_email,
                "expires_label": _expires_label(record.expires_at),
                "error": "Please enter your full name and tick the permission box to continue.",
            },
        )

    record.parent_guardian_name = cleaned_name
    try:
        record.parent_relationship = ParentRelationship(parent_relationship)
    except ValueError:
        record.parent_relationship = ParentRelationship.PARENT

    verification_duration_ms = None
    if record.last_sent_at:
        sent_at = (
            record.last_sent_at
            if record.last_sent_at.tzinfo
            else record.last_sent_at.replace(tzinfo=timezone.utc)
        )
        verification_duration_ms = int(
            (datetime.now(timezone.utc) - sent_at).total_seconds() * 1000
        )

    consent_service.grant_consent(
        db,
        child,
        record,
        method=ConsentMethod.EMAIL_PLUS_CONFIRMATION,
        policy_version=settings.consent_policy_version,
    )

    analytics.track(
        db,
        "vpc_email_verified",
        user=child,
        properties={
            "verification_duration_ms": verification_duration_ms,
            "consent_policy_version": settings.consent_policy_version,
        },
    )
    analytics.track(
        db,
        "parental_consent_completed",
        user=child,
        properties={
            "vpc_path": str(ConsentMethod.EMAIL_PLUS_CONFIRMATION),
            "consent_granted": True,
            "consent_duration_ms": verification_duration_ms,
        },
    )

    return _result(
        request,
        status_code=200,
        heading="Thank you \u2014 permission recorded",
        message=(
            f"You've given permission for {child_name} to use Anointed. "
            "We've saved a record of this consent."
        ),
        icon="\u2705",
        banner_class="success",
        child_name=child_name,
        show_return_hint=True,
    )
