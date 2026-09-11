# Production image. Dockerfile.dev is the local/test image (has --reload, dev deps);
# this one is what actually gets deployed.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . /srv

# Migrations run before the server starts so a bad migration fails the deploy
# instead of leaving the API up against a half-migrated schema.
CMD alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
