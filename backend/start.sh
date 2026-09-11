#!/bin/sh
# Railway execs the service's startCommand as a raw argv list, not through a
# shell -- an inline "a && b --port $PORT" override arrives with its quoting,
# $PORT expansion, and && all taken literally, which is what crash-looped the
# service (uvicorn received the four characters "$PORT" as its --port value).
# A real shell only runs once this script itself is invoked, so $PORT expands
# correctly here. The Dockerfile's own CMD does this already and needs no
# override; this file exists only for the platform that requires one.
set -e
alembic upgrade head
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
