# 13 — DevOps & CI (OPS) · Phase 0 onward

- [ ] **OPS-1 — Backend CI** *(deps: FND-2)*
  GitHub Actions on PR: ruff, pytest (with postgres/redis services), alembic upgrade check.
  *AC: red PR on lint/test/migration failure.*

- [ ] **OPS-2 — Flutter CI** *(deps: FND-4)*
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
