# 03 — Jobs, quotes & pricing (JOB) · Phase 1

The core domain: platform config, quoting, the job record and its state machine.

- [ ] **JOB-1 — Jobs + related models** *(deps: AUTH-1)*
  `jobs` (PLAN §2.2: PostGIS points, statuses, per-transition timestamps, quoted/final price, config snapshot jsonb), `job_offers`, `customer_vehicles`, `driver_location_snapshots`.
  *AC: migrations apply; GiST index on pickup geom.*

- [ ] **JOB-2 — `platform_config` + audit** *(deps: FND-2)*
  Versioned key/value config: pricing per vehicle type, commission (mode percent|flat, rate per type), settlement (balance_cap, period), dispatch (offer TTL, radius, widening). Redis-cached with bust-on-write; every change records changed_by + previous value.
  *AC: config read helper hits Redis; update invalidates cache; audit rows written.*

- [ ] **JOB-3 — Job state machine service** *(deps: JOB-1)*
  Allowed-transitions map for `requested → matching → assigned → en_route_pickup → arrived_pickup → loading → in_transit → delivered → completed`, plus `cancelled` / `no_drivers`. Each transition: timestamp, location snapshot, event emit (WS + FCM hook points).
  *AC: unit tests cover every legal and illegal transition; cancellation rules (customer free until assigned + grace; driver cancel → back to matching).*

- [ ] **JOB-4 — Pricing service + quote endpoint** *(deps: JOB-2, FND-6)*
  `POST /v1/jobs/quote`: pickup/dropoff/vehicle_type → Google Directions road distance → `base + per_km × km`, min fare, COP. Quote cached ~10 min with an id.
  *AC: quote uses live config values; deterministic tests with mocked Directions.*

- [ ] **JOB-5 — Create / get / list / cancel endpoints** *(deps: JOB-3, JOB-4)*
  `POST /v1/jobs` (from a quote id) → status `matching`; `GET /v1/jobs/{id}`; `GET /v1/jobs?role=` history with pagination; `POST /v1/jobs/{id}/cancel` enforcing JOB-3 rules. Job stores the pricing/commission config snapshot.
  *AC: customer can only see own jobs, driver only assigned ones; snapshot present on created jobs.*

- [ ] **JOB-6 — Status transition endpoint (driver)** *(deps: JOB-3)*
  `POST /v1/jobs/{id}/status` — driver advances the machine; validates the caller is the assigned driver.
  *AC: wrong-driver and wrong-order transitions return 409/403; happy path covered by an integration test through all states.*
