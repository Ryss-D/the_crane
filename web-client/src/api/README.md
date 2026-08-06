# src/api — typed client

`types.ts` is **hand-written** and mirrors the backend contract (job status
union, vehicle types, `Quote`, `Job`, `TrackInfo`). It exists so the UI can be
built before the FastAPI spec stabilizes.

## Generated OpenAPI client (WEB-1)

`src/api/generated.ts` is generated from the backend's `/openapi.json` via
[`openapi-typescript`](https://openapi-ts.dev/):

```sh
npm run client:generate   # openapi-typescript ../backend/openapi.json → src/api/generated.ts
npm run client:check      # regenerates to a temp file, fails if it differs (drift check, CI-safe)
```

**Depth chosen: generate + drift-check, not a full `types.ts` replacement.**
`types.ts` stays hand-written for now. Rationale: a full migration means
mapping every hand-written interface (`Quote`, `Job`, `TrackInfo`, `Driver`,
`UserProfile`, …) onto the generated `components['schemas'][...]` shapes
across every consumer (`RequestPage`, `TrackingPage`, `DriverCard`, `mock.ts`,
`client.ts`, `AuthProvider`, …) — real value, but a bigger and riskier change
than fits alongside the rest of this session's work. The smaller step still
kills the actual bug (`client:generate` was a non-functional stub) and adds
the missing CI check that used to let `types.ts` silently drift from the
real contract (see the "align Job/TrackInfo" fix commits in git log — this
is exactly the class of bug a drift check catches next time). Revisit the
full replacement when there's a dedicated slot for it; `generated.ts` is
already sitting there to migrate onto incrementally.

**Where the spec comes from.** `openapi-typescript` reads a spec file, not
a live server: `client:generate`/`client:check` point at
`../backend/openapi.json`, a snapshot **checked into the backend repo**
(`backend/openapi.json`), not a running `uvicorn` process. Two reasons:
1. `FastAPI.openapi()` needs no database/Redis at all — `create_app()` only
   registers routes and Pydantic models at import time, every DB/Redis
   dependency is a lazy `Depends` resolved per-request
   (`backend/scripts/dump_openapi.py`). So there's no need to actually boot
   a server just to read its schema.
2. A checked-in snapshot means both CI checks below run with zero service
   containers and are fully deterministic.

To refresh the snapshot after a backend contract change:

```sh
cd backend && uv run python scripts/dump_openapi.py   # no DB/Redis/server needed, just `uv sync`
# or, from web-client/:
npm run spec:refresh
```

(If you'd rather generate straight from a live dev server instead of the
snapshot — e.g. while iterating locally against `uv run uvicorn app.main:app
--reload` from `backend/`, serving on `http://localhost:8000` — point
`client:generate` at `http://localhost:8000/openapi.json` instead of the
snapshot path; openapi-typescript accepts a URL or a file path
interchangeably. The snapshot is what's wired into CI, since it needs no
live process.)

**CI wiring** (closes the loop across both workflows, no live backend or
service containers anywhere):
- `.github/workflows/backend.yml`'s `lint` job re-dumps the spec and diffs
  it against the committed `backend/openapi.json` — catches "backend code
  changed but nobody refreshed the snapshot."
- `.github/workflows/web-client.yml` runs `npm run client:check` — catches
  "the snapshot changed (or generated.ts was hand-edited) but nobody
  reran `client:generate`."

Together these catch "the checked-in client doesn't match the CURRENT
backend code," just via a checked-in intermediate snapshot rather than a
live server round-trip in CI.

## Seam

- `client.ts` — `CraneApi` interface + `HttpApi` (real fetch wrappers for
  `POST /v1/jobs/quote`, `POST /v1/jobs`, `GET /v1/jobs/{id}`,
  `GET /v1/track/{token}`).
- `mock.ts` — `MockApi`: seeded in-memory data with latency and a timed status
  progression. Seeded demo routes: `/jobs/demo`, `/t/demo-token`.
- `index.ts` — picks the implementation: `VITE_USE_MOCKS` defaults to `true`;
  set it to `false` (plus `VITE_API_BASE_URL`) to hit the real backend.
