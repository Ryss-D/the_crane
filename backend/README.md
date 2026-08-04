# The Crane — Backend (FastAPI)

Python API for dispatch, pricing, jobs, payments, and admin. See `docs/PLAN.md` §2 for the architecture and `docs/tasks/` for the backlog.

## Stack
- FastAPI + async SQLAlchemy + Alembic
- PostgreSQL + PostGIS (geo queries), Redis (live driver locations, pub/sub, config cache)
- Firebase Admin (ID token verification), FCM (push)
- uv + ruff + pytest

## Planned layout

```
backend/
├── app/
│   ├── main.py                 # FastAPI app, routers, lifespan
│   ├── core/                   # config, security (Firebase JWT), database
│   ├── models/                 # SQLAlchemy: user, driver, vehicle, job, payment, ledger, config
│   ├── schemas/                # Pydantic request/response
│   ├── api/                    # auth, users, drivers, jobs, payments, admin, ws
│   ├── services/               # dispatch, pricing, jobs (state machine), notifications, payments/
│   └── workers/                # offer timeouts, reconciliation
├── alembic/
├── tests/
├── pyproject.toml
└── Dockerfile
```

Scaffolded in task `FND-2` (see `docs/tasks/01-foundations.md`).
