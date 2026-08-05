# src/api — typed client

`types.ts` is **hand-written** and mirrors the backend's admin contract
(docs/PLAN.md §2.2 `platform_config`, §2.6 admin API surface). It exists so
the ADM-3..6 UI can be built before the FastAPI admin router's OpenAPI spec
stabilizes.

**TODO(openapi):** once the backend's `/openapi.json` includes the `/v1/admin/*`
routes (ADM-2 AC) and is stable, replace `types.ts` with generated types:

```sh
npm run client:generate   # openapi-typescript → src/api/generated.ts
```

and add the CI check that regenerating produces no diff (spec/client sync).
The `client:generate` script is currently a failing placeholder on purpose.

## Seam

- `client.ts` — `CraneAdminApi` interface + `HttpApi` (real fetch wrappers,
  Bearer token from the auth seam, for `GET/PUT /v1/admin/config[/{key}]`,
  `GET /v1/admin/drivers` + verify/block/unblock, `GET /v1/admin/jobs[/{id}]`
  - cancel, `GET /v1/admin/ledger` + settle).
- `mock.ts` — `MockApi`: seeded in-memory data (~8 drivers, ~15 jobs across
  every status, config at the launch defaults, a driver ledger with entries
  that sum to each seeded balance). No network, small latency for realistic
  loading states.
- `index.ts` — picks the implementation: `VITE_USE_MOCKS` defaults to `true`;
  set it to `false` (plus `VITE_API_BASE_URL`) to hit the real backend.

## Known drift vs. the real backend (as of this scaffold)

`backend/app/api/admin.py` only has a `GET /v1/admin/ping` stub so far — the
real ADM-2 router (config/drivers/jobs/ledger) hasn't landed. `types.ts` and
`client.ts` are this app's best-effort mirror of docs/PLAN.md §2.2/§2.6, not
a confirmed contract. Known naming differences already visible in the
backend's seed data (`backend/scripts/seed.py`, `backend/tests/conftest.py`)
that will likely need reconciling once ADM-2 ships:

- pricing sub-keys: backend seed uses `base`/`per_km`/`min`; this app's
  `VehiclePricing` uses `base_fare`/`per_km`/`min_fare`.
- settlement: backend seed uses `period`; this app's `SettlementConfig` uses
  `settlement_period`.
- dispatch: backend seed uses `radius_widen_factor` (a multiplier) plus
  `cancel_grace_seconds` and `rejection_cooldown_minutes`; this app's
  `DispatchConfig` only has `radius_widening_steps_km` (an explicit step
  list) and is missing the other two fields.
- commission: backend config shape branches by `mode` (`rate` for `percent`,
  `amount` for `flat`); this app's `CommissionConfig` always uses a single
  `rate` record regardless of mode.
- the ledger drill-down (`getLedgerEntries`) assumes `GET /v1/admin/ledger`
  accepts `?driver_id=`; the documented contract only lists the balances
  endpoint, so this is a guess pending ADM-2.

None of this blocks UI work (the mock is the source of truth for now), but
whoever wires `HttpApi` up for real should re-check every field name against
the live `/openapi.json` rather than assume this file is correct.
