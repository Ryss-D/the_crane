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

  Audited (2026-08-31): `.env.example` already exists for all three
  non-Flutter workspaces (`backend/`, `web-client/`, `admin/`) -- that part
  of the AC was already met before this pass. Ran a real secret scan
  (`git ls-files` + grep for API-key-shaped strings across the tracked
  tree): no `.env`/`.env.local` files are tracked anywhere, and the only
  tracked files containing what look like API keys are `google-services.json`,
  `GoogleService-Info.plist`, and the two `fly.toml`s' `[build.args]` --
  all deliberate and correct to commit, not a leak: Firebase client config
  and a referrer-locked Maps key are meant to be public once shipped in an
  app bundle/JS build (documented already in OPS-5's own note and
  `backend/README.md`'s Firebase section). **AC's "nothing secret in git"
  clause: verified true.**

  Still not done, and this is the actual remaining scope of the task's own
  title ("dev/prod separation"): there is exactly **one** environment
  everywhere right now -- one Firebase project, one set of Maps keys, no
  Wompi account at all yet (sandbox or prod), one Fly Postgres. Building
  real separation means standing up a second Firebase project + a second
  set of restricted Maps keys + Wompi sandbox creds + a second DB, which is
  account-creation/credential work only a human can do (same external
  blockers already tracked elsewhere: FND-6's iOS key, PAY-1..5's Wompi
  account) -- there's no code left to write for this task until those
  accounts exist to point config at. Left unchecked for that reason.

- [ ] **OPS-5 — Web/admin CI + deploy** *(deps: WEB-1, ADM-1)*
  Lint/typecheck/build on PR; preview deploys per PR; prod deploy on `main`.
  *AC: PR preview URL posted automatically.*
  Built and live-verified (2026-08-31): both deployed to Fly.io (not the
  original task line's Cloudflare Pages/Vercel — kept everything on one
  platform alongside the backend, see OPS-3) as static sites —
  `the-crane-web`/`the-crane-admin`, each a multi-stage Docker build
  (`node:22-alpine` running `vite build`, served by `nginx:alpine` with an
  SPA fallback for react-router) via `web-client/Dockerfile` and
  `admin/Dockerfile`. `VITE_*` env vars are baked in as Docker build ARGs
  (`fly.toml`'s `[build.args]`), not runtime secrets — Vite compiles them
  into the JS bundle at build time, and none of them are actually secret
  once built anyway (Firebase web config is meant to be public; the Maps
  key is protected by its own referrer restriction).

  Deployed with `VITE_USE_MOCKS=true` deliberately, not pointed at the
  real backend yet: flipping that needs `FIREBASE_CREDENTIALS_JSON` set on
  `the-crane-api` first (a manual step for the user, see the OPS-3 note),
  and shipping "real mode" before that would just 401 on every authed
  call. `the-crane-api`'s `CORS_ORIGINS` already includes both new domains
  for whenever that flip happens.

  GitHub Actions auto-deploy on push to `dev`
  (`.github/workflows/deploy-web-client.yml`, `deploy-admin.yml`), each
  with its own app-scoped Fly deploy token. **Not built**: PR preview URLs
  — Fly has no built-in per-PR preview the way Cloudflare Pages/Vercel do;
  replicating that needs custom per-PR app create/destroy logic, a
  separate follow-up. **Not built**: a distinct prod deploy on `main` —
  only the single `dev` environment exists right now, matching OPS-3's own
  scope-to-"(dev)" choice.

  A real, non-obvious constraint hit while deploying: the Fly org's
  machine limit — `fly deploy` creates a second machine for HA by default,
  and the org (which also runs several unrelated apps) hit its cap
  mid-deploy. Fixed by scaling every app in this project down to a single
  machine (`--ha=false` on deploy, `fly scale count 1` on the two apps
  already past that point) — a deliberate choice for a dev/demo
  environment, not just a workaround; revisit if real uptime requirements
  ever call for redundancy here.

  Real follow-up flagged, not done here (needs an interactive `gcloud auth
  login` this session couldn't do non-interactively): the Web Google Maps
  key's HTTP-referrer restriction (Google Cloud Console) is still
  `localhost:5173`/`5174` only — add `https://the-crane-web.fly.dev/*` and
  `https://the-crane-admin.fly.dev/*` or the map components on both
  deployed sites silently show no tiles.

  AC verified directly: `curl https://the-crane-web.fly.dev/health` and
  `https://the-crane-admin.fly.dev/health` both return `ok` (HTTP 200)
  after a real deploy; `curl .../` on both returns real rendered HTML, not
  a blank/broken page.

- [ ] **OPS-6 — Observability baseline** *(deps: OPS-3)*
  Structured logging (request id, job id), Sentry for API + Flutter + web, basic uptime check.
  *AC: a forced API exception appears in Sentry with request context.*
