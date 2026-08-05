# The Crane — Backend (FastAPI)

Python API for dispatch, pricing, jobs, payments, and admin. See `docs/PLAN.md` §2 for the architecture and `docs/tasks/` for the backlog.

## Stack
- FastAPI + async SQLAlchemy + Alembic
- PostgreSQL + PostGIS (geo queries), Redis (live driver locations, pub/sub, config cache)
- Firebase Admin (ID token verification), FCM (push)
- uv + ruff + pytest

## Layout

```
backend/
├── app/
│   ├── main.py                 # FastAPI app factory, routers, lifespan
│   ├── core/                   # config (pydantic-settings), security (Firebase JWT), database
│   ├── models/                 # SQLAlchemy: user (driver, vehicle, job, payment, ledger, config later)
│   ├── schemas/                # Pydantic request/response
│   ├── api/                    # users (/v1/me), admin (auth, drivers, jobs, payments, ws later)
│   ├── services/               # (later) dispatch, pricing, jobs (state machine), notifications
│   └── workers/                # (later) offer timeouts, reconciliation
├── alembic/                    # async migrations (url comes from DATABASE_URL via app config)
├── scripts/seed.py             # idempotent dev seed (admin user)
├── tests/
├── docker-compose.yml          # api + postgis + redis
├── pyproject.toml              # uv-managed
└── Dockerfile
```

## Run locally (Docker — full stack)

```bash
cd backend
docker compose up --build
# api runs `alembic upgrade head` then serves on http://localhost:8000
curl http://localhost:8000/health          # {"status":"ok"}
docker compose exec api uv run python scripts/seed.py   # seed the dev admin user
```

## Run locally (no Docker)

Requires [uv](https://docs.astral.sh/uv/) and a Postgres+PostGIS and Redis reachable at the
URLs in `.env` (copy `.env.example` to `.env` and adjust).

```bash
cd backend
uv sync                        # installs Python 3.12 + deps into .venv
uv run alembic upgrade head    # apply migrations
uv run python scripts/seed.py  # seed dev admin (idempotent)
uv run uvicorn app.main:app --reload
```

Interactive docs at http://localhost:8000/docs.

## Environment

See `.env.example`: `DATABASE_URL`, `REDIS_URL`, `FIREBASE_CREDENTIALS_PATH`, `ENV`.
The app boots without Firebase credentials — firebase-admin is initialized lazily, only when
a token actually needs verifying (FND-1 provides the service-account JSON).

## Auth model

Every protected route takes `Authorization: Bearer <firebase_id_token>`. The
`get_current_user` dependency (`app/core/security.py`) verifies the token and resolves it to
a `users` row — 401 on missing/invalid token, 404 if the user never synced. `require_admin`
additionally enforces `role=admin` (403 otherwise).

## Tests & lint

```bash
uv run pytest        # in-memory aiosqlite + mocked token verifier; no services needed
uv run ruff check .
uv run ruff format --check .
```

## Migrations

```bash
uv run alembic revision --autogenerate -m "describe change"
uv run alembic upgrade head
```

The first migration enables the PostGIS extension (skipped on sqlite in tests).
