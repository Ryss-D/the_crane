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

- [ ] **OPS-3 — Backend deploy (dev)** *(deps: FND-3)*
  Cloud Run / Fly.io / Railway: containerized API + managed Postgres (with PostGIS) + Redis; secrets via the platform's secret store; auto-deploy `dev` branch.
  *AC: dev API reachable over HTTPS with migrations applied on deploy.*

- [ ] **OPS-4 — Environments & secrets hygiene** *(deps: OPS-3)*
  dev/prod separation everywhere: Firebase projects, Maps keys, Wompi sandbox/prod, DB. `.env.example` files per workspace; nothing secret in git.
  *AC: fresh clone + documented steps reaches a running local stack.*

- [ ] **OPS-5 — Web/admin CI + deploy** *(deps: WEB-1, ADM-1)*
  Lint/typecheck/build on PR; preview deploys per PR; prod deploy on `main`.
  *AC: PR preview URL posted automatically.*

- [ ] **OPS-6 — Observability baseline** *(deps: OPS-3)*
  Structured logging (request id, job id), Sentry for API + Flutter + web, basic uptime check.
  *AC: a forced API exception appears in Sentry with request context.*
