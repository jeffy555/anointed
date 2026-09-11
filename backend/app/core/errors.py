"""Uniform error envelope so the Flutter client can branch on a stable ``code``."""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.integrations.base import IntegrationError, IntegrationNotConfigured

logger = logging.getLogger("anointed.errors")


class AppError(HTTPException):
    """Domain error with a machine-readable code and a user-safe message."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        *,
        extra: dict | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        detail = {"code": code, "message": message}
        if extra:
            detail.update(extra)
        super().__init__(status_code=status_code, detail=detail, headers=headers)


def bad_request(code: str, message: str, **extra) -> AppError:
    return AppError(status.HTTP_400_BAD_REQUEST, code, message, extra=extra or None)


def forbidden(code: str, message: str, **extra) -> AppError:
    return AppError(status.HTTP_403_FORBIDDEN, code, message, extra=extra or None)


def not_found(code: str, message: str, **extra) -> AppError:
    return AppError(status.HTTP_404_NOT_FOUND, code, message, extra=extra or None)


def conflict(code: str, message: str, **extra) -> AppError:
    return AppError(status.HTTP_409_CONFLICT, code, message, extra=extra or None)


def too_many_requests(code: str, message: str, retry_after: int, **extra) -> AppError:
    return AppError(
        status.HTTP_429_TOO_MANY_REQUESTS,
        code,
        message,
        extra=extra or None,
        headers={"Retry-After": str(retry_after)},
    )


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(HTTPException)
    async def _http_exception(_: Request, exc: HTTPException) -> JSONResponse:
        detail = exc.detail
        if not isinstance(detail, dict):
            detail = {"code": _code_for_status(exc.status_code), "message": str(detail)}
        return JSONResponse(status_code=exc.status_code, content=detail, headers=exc.headers)

    @app.exception_handler(RequestValidationError)
    async def _validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={
                "code": "validation_error",
                "message": "Some of that information wasn't valid.",
                "fields": [
                    {"field": ".".join(str(part) for part in err["loc"][1:]), "error": err["msg"]}
                    for err in exc.errors()
                ],
            },
        )

    @app.exception_handler(IntegrationNotConfigured)
    async def _not_configured(_: Request, exc: IntegrationNotConfigured) -> JSONResponse:
        # Loud on the server, vague to the client: a production deploy missing
        # credentials is an operator problem, not something to explain to a child.
        logger.error("integration misconfigured: %s", exc)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"code": "service_unavailable", "message": exc.safe_message},
        )

    @app.exception_handler(IntegrationError)
    async def _integration_error(_: Request, exc: IntegrationError) -> JSONResponse:
        logger.warning("integration error: %s", exc)
        return JSONResponse(
            status_code=status.HTTP_502_BAD_GATEWAY,
            content={"code": "upstream_error", "message": exc.safe_message},
        )

    @app.exception_handler(SQLAlchemyError)
    async def _database_error(_: Request, exc: SQLAlchemyError) -> JSONResponse:
        logger.exception("database error: %s", exc)
        from app.core.config import settings

        message = (
            "The server database is unavailable. Restart the API after checking DATABASE_URL."
            if settings.environment == "development"
            else "That service is unavailable right now."
        )
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"code": "database_unavailable", "message": message},
        )


def _code_for_status(status_code: int) -> str:
    return {
        400: "bad_request",
        401: "not_authenticated",
        403: "forbidden",
        404: "not_found",
        409: "conflict",
        429: "rate_limited",
    }.get(status_code, "error")
