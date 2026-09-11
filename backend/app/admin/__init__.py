"""Embedded admin dashboard mounted at ``/admin`` (design-spec §23)."""

from __future__ import annotations

from fastapi import FastAPI
from sqladmin import Admin

from app.admin.auth import AdminAuth
from app.admin.reports import AuditLogExportView, ContentPublishView, ReportsView
from app.admin.views import ALL_VIEWS
from app.core.config import settings
from app.core.database import engine


def setup_admin(app: FastAPI) -> Admin:
    admin = Admin(
        app,
        engine,
        base_url="/admin",
        title="Anointed Admin",
        authentication_backend=AdminAuth(secret_key=settings.admin_session_secret),
    )
    for view in ALL_VIEWS:
        admin.add_view(view)
    for custom_view in (ReportsView, ContentPublishView, AuditLogExportView):
        admin.add_view(custom_view)
    return admin
