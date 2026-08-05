# src/api — typed client

`types.ts` is **hand-written** and mirrors the backend contract (job status
union, vehicle types, `Quote`, `Job`, `TrackInfo`). It exists so the UI can be
built before the FastAPI spec stabilizes.

**TODO(openapi):** once the backend's `/openapi.json` is stable (WEB-1 AC),
replace `types.ts` with generated types:

```sh
npm run client:generate   # openapi-typescript → src/api/generated.ts
```

and add the CI check that regenerating produces no diff (spec/client sync).
The `client:generate` script is currently a failing placeholder on purpose.

## Seam

- `client.ts` — `CraneApi` interface + `HttpApi` (real fetch wrappers for
  `POST /v1/jobs/quote`, `POST /v1/jobs`, `GET /v1/jobs/{id}`,
  `GET /v1/track/{token}`).
- `mock.ts` — `MockApi`: seeded in-memory data with latency and a timed status
  progression. Seeded demo routes: `/jobs/demo`, `/t/demo-token`.
- `index.ts` — picks the implementation: `VITE_USE_MOCKS` defaults to `true`;
  set it to `false` (plus `VITE_API_BASE_URL`) to hit the real backend.
