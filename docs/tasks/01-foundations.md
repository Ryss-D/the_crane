# 01 — Foundations (FND) · Phase 0

Workspace scaffolding and the plumbing every other feature stands on.

- [ ] **FND-1 — Firebase project setup**
  Create Firebase project (dev + prod), enable Phone Auth (+57) and FCM, download platform configs, create service account for the backend.
  *AC: Flutter dev flavor signs in with a test phone number; backend service-account JSON available via env.*

- [ ] **FND-2 — Backend scaffold** *(deps: —)*
  FastAPI app per `backend/README.md` layout: `main.py`, `core/config.py` (pydantic-settings), `core/database.py` (async SQLAlchemy), Alembic init, health endpoint, Dockerfile.
  *AC: `docker compose up` serves `GET /health` 200; `alembic upgrade head` runs clean.*

- [ ] **FND-3 — Local infra (Docker Compose)** *(deps: FND-2)*
  Compose file: api + `postgis/postgis` + `redis`. Seed script for a dev admin user and default `platform_config` values.
  *AC: one command brings up the full local stack with seeded config.*

- [ ] **FND-4 — Flutter app restructure** *(deps: —)*
  Rework boilerplate into the feature-first layout (PLAN §3.2): `app/` (router, theme, providers), `core/` (api, ws, models), `features/`. Add Riverpod, go_router, dio, freezed, flavors (dev/prod via `--dart-define-from-file`).
  *AC: app builds both flavors; router shows a placeholder auth screen; codegen (`build_runner`) wired.*

- [ ] **FND-5 — Firebase token verification middleware** *(deps: FND-2)*
  FastAPI dependency: `Authorization: Bearer <firebase_id_token>` → verified claims → `users` row (404 if not synced). Admin variant checks `role=admin`.
  *AC: protected route rejects missing/bad tokens (401), unknown users (404); test with emulator or mocked verifier.*

- [ ] **FND-6 — Google Maps keys & billing** *(deps: —)*
  Enable Maps SDKs (Android/iOS/JS), Places, Directions. Separate restricted keys per platform; bias Places to Valle de Aburrá.
  *AC: keys in env files per flavor; a map renders in the Flutter dev app.*
