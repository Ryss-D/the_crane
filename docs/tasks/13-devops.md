# 13 — DevOps & CI (OPS) · Phase 0 onward

- [x] **OPS-1 — Backend CI** *(deps: FND-2)*
  GitHub Actions on PR: ruff, pytest (with postgres/redis services), alembic upgrade check.
  *AC: red PR on lint/test/migration failure.*
  Known flake (not yet root-caused): `tests/test_ws.py::test_location_from_assigned_driver_relays_to_customer`
  intermittently fails with `no such table: driver_location_snapshots` when run as
  part of the full suite (passes every time in isolation) -- smells like a
  SQLite/`StaticPool` timing issue specific to this test's use of a sync
  `starlette.testclient.TestClient` websocket alongside the async `client` fixture
  (see the file's own docstring on why it needs both). Hasn't reproduced on repeated
  isolated runs; noted here rather than chased down given how rarely it fires.

- [x] **OPS-2 — Flutter CI** *(deps: FND-4)*
  flutter analyze + test on PR; build check for both flavors.
  *AC: analyze warnings fail the build.*

- [x] **OPS-3 — Backend deploy (dev)** *(deps: FND-3)*
  Cloud Run / Fly.io / Railway: containerized API + managed Postgres (with PostGIS) + Redis; secrets via the platform's secret store; auto-deploy `dev` branch.
  *AC: dev API reachable over HTTPS with migrations applied on deploy.*
  Built and live-verified (2026-08-31), Fly.io chosen: `the-crane-api`
  (`backend/fly.toml`, `iad` region — no Bogotá/Medellín region exists on
  Fly yet; Ashburn was picked over Sao Paulo for more consistent LatAm
  backbone routing), deployed straight from the existing `backend/Dockerfile`,
  scales to zero when idle. `[deploy].release_command` runs
  `alembic upgrade head` once per deploy before the new version goes live —
  no separate migration step needed.

  Postgres: **not** Fly's own managed "postgres-flex" offering — that image
  does not support the postgis extension (confirmed directly: `CREATE
  EXTENSION postgis` crashed the server during setup). Deployed instead as
  a plain Fly app (`the-crane-db`, `deploy/postgres/fly.toml`) running the
  exact `postgis/postgis:16-3.4` image local dev and CI already use, on a
  3GB volume, reachable only over Fly's private network
  (`the-crane-db.internal:5432`) — no `[[services]]` block, never exposed
  publicly. That image's own entrypoint auto-creates the `crane`
  database/role and loads PostGIS — confirmed via `psql`: `postgis_version()`
  returns `3.4 USE_GEOS=1 USE_PROJ=1 USE_STATS=1`.

  Redis: Fly's first-party Upstash integration (`the-crane-redis`,
  pay-as-you-go plan — no fixed monthly cost, $0.20/100K commands).

  Secrets set via `fly secrets set` (never committed): `DATABASE_URL`,
  `REDIS_URL`, `ENV=dev`, `CORS_ORIGINS`. Deliberately **not** set yet:
  `GOOGLE_MAPS_API_KEY`, `WOMPI_*` (neither key exists — the app degrades
  gracefully without them, per their own fallback design), and
  `FIREBASE_CREDENTIALS_JSON` (the service-account JSON needs to be set by
  the user directly from their own terminal — `fly.toml`'s `[processes]`
  writes it to a file and points `FIREBASE_CREDENTIALS_PATH` at it if
  present — so the credential never has to be pasted anywhere else).

  GitHub Actions auto-deploy: `.github/workflows/deploy-backend.yml`
  triggers on push to `dev` (path-filtered to `backend/**`), using a
  scoped Fly deploy token (`FLY_API_TOKEN` repo secret, app-scoped, not a
  full account token). Not yet exercised by an actual push to `dev` — the
  live verification above was a direct `flyctl deploy` from this session,
  not the CI path itself, since this work hasn't merged past `dev` yet.

  AC fully met and directly verified: `curl https://the-crane-api.fly.dev/health`
  returns `{"status":"ok"}` (HTTP 200) after a real deploy that ran real
  migrations against the real Postgres above.

  Deliberately deferred, called out here since the task's own title says
  "(dev)": this is a single dev environment, not dev+prod separation (see
  OPS-4) — migrating to GCP later, as discussed, would mean standing up
  Cloud Run + Cloud SQL (with the PostGIS extension enabled — Cloud SQL
  does support it, unlike Fly's managed offering) + Memorystore and
  retiring this Fly setup, not running both simultaneously.

- [ ] **OPS-4 — Environments & secrets hygiene** *(deps: OPS-3)*
  dev/prod separation everywhere: Firebase projects, Maps keys, Wompi sandbox/prod, DB. `.env.example` files per workspace; nothing secret in git.
  *AC: fresh clone + documented steps reaches a running local stack.*

- [ ] **OPS-5 — Web/admin CI + deploy** *(deps: WEB-1, ADM-1)*
  Lint/typecheck/build on PR; preview deploys per PR; prod deploy on `main`.
  *AC: PR preview URL posted automatically.*

- [ ] **OPS-6 — Observability baseline** *(deps: OPS-3)*
  Structured logging (request id, job id), Sentry for API + Flutter + web, basic uptime check.
  *AC: a forced API exception appears in Sentry with request context.*
