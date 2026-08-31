# 03 — Jobs, quotes & pricing (JOB) · Phase 1

The core domain: platform config, quoting, the job record and its state machine.

- [x] **JOB-1 — Jobs + related models** *(deps: AUTH-1)*
  `jobs` (PLAN §2.2: PostGIS points, statuses, per-transition timestamps, quoted/final price, config snapshot jsonb), `job_offers`, `customer_vehicles`, `driver_location_snapshots`. Capacity/vehicle-type filtering reads from the `trucks` table (see AUTH-5), keeping dispatch fleet-ready.
  *AC: migrations apply; GiST index on pickup geom.*
  Deviation: pickup/dropoff are plain lat/lng floats, not PostGIS geometry — geoalchemy2 on sqlite needs SpatiaLite, which would make tests service-dependent. PostGIS geometry + GiST is deferred to a later geo-scale pass; Redis geo-sets (DSP-1) cover current dispatch-radius needs.

- [x] **JOB-2 — `platform_config` + audit** *(deps: FND-2)*
  Versioned key/value config: pricing per vehicle type, commission (mode percent|flat, rate per type), settlement (balance_cap, period), dispatch (offer TTL, radius, widening). Redis-cached with bust-on-write; every change records changed_by + previous value.
  *AC: config read helper hits Redis; update invalidates cache; audit rows written.*

- [x] **JOB-3 — Job state machine service** *(deps: JOB-1)*
  Allowed-transitions map for `requested → matching → assigned → en_route_pickup → arrived_pickup → loading → in_transit → delivered → completed`, plus `cancelled` / `no_drivers`. Each transition: timestamp, location snapshot, event emit (WS + FCM hook points).
  *AC: unit tests cover every legal and illegal transition; cancellation rules (customer free until assigned + grace; driver cancel → back to matching).*

- [x] **JOB-4 — Pricing service + quote endpoint** *(deps: JOB-2, FND-6)*
  `POST /v1/jobs/quote`: pickup/dropoff/vehicle_type → Google Directions road distance → `base + per_km × km`, min fare, COP. Quote cached ~10 min with an id.
  *AC: quote uses live config values; deterministic tests with mocked Directions.*
  Note: falls back to a haversine×1.3 road-distance estimate when no Google Maps API key is configured (FND-6 pending) — same formula either way once a key is set.

  Follow-up (FND-6): now that Android/iOS/Web client Maps keys exist, three new
  proxy endpoints exist for the exact same reason `GoogleDirectionsClient` does
  — Android/iOS app-restricted keys only work through the native Maps SDK's own
  attestation, not a plain REST call from Dart/JS, so no client app can call
  Places/Directions REST endpoints directly with the keys it already has.
  `GET /v1/places/autocomplete?input=` and `GET /v1/places/details/{place_id}`
  (new `app/services/places.py`/`app/api/places.py`) proxy Google's classic
  Places Autocomplete/Details endpoints, biased to the Valle de Aburrá
  (`location`/`radius`/`components=country:co`). `GET
  /v1/directions/route?origin_lat=&origin_lng=&dest_lat=&dest_lng=` (same
  `app/api/places.py`) returns a decoded polyline (`app/services/pricing.py`
  gained `decode_polyline` — the standard algorithm, no new dependency — and
  `GoogleDirectionsClient.route_polyline`, sharing its HTTP call with
  `road_distance_km` via a new shared `_fetch_route` rather than duplicating
  it; `road_distance_km`'s own behavior/callers are unchanged, verified by the
  full existing `test_quotes.py` suite still passing unmodified).

  All three degrade gracefully without a key exactly like pricing already did:
  autocomplete returns `{"predictions": []}` (never an error — nothing sensible
  to fake, and a client with no suggestions just falls back to manual entry);
  details and route both 503 (`HaversineFallback.route_polyline` raises the
  same 503 a missing key does — a fake polyline would just be the two
  endpoints, not a real route, so there's no honest fallback to fake here the
  way haversine-for-distance is). 13 new tests (`tests/test_places_api.py`,
  including the polyline decoder verified against Google's own canonical
  encoding example), full backend suite green (305 passed, up from 292).
  `openapi.json` regenerated (`web-client`'s `client:check` CI job would
  otherwise flag it as stale against these new routes).

  Still no server-side key: `google_maps_api_key` (`.env.example`, now
  documented) is a **4th key**, distinct from the Android/iOS/Web client keys
  already set up this session — server-side, scoped to Places API + Directions
  API, ideally IP-restricted once real hosting exists (OPS-3, not yet). Every
  code path above is real and tested, but is currently only ever exercising
  its no-key fallback branch — no live call against a real key has happened.

  Follow-up: `POST /v1/jobs/quote` is now deliberately public — dropped the
  unused `CurrentUser` dependency from `create_quote` (`app/api/jobs.py`;
  `build_quote` never read the caller's identity for anything, dead
  parameter). Driven by a web-client UX fix (see `10-web-client.md`'s WEB-1
  follow-up): forcing phone sign-in before a customer can even see a price
  was bad ordering, and quoting is stateless/anonymous by nature — only
  `create_job` right below it, which actually commits to something, still
  requires auth. `test_quote_requires_auth` (asserted 401) replaced with
  `test_quote_works_without_auth` (asserts a real 200 priced quote, no
  `Authorization` header sent at all). `openapi.json` regenerated. Full
  suite green (338 passed), ruff clean.

  Follow-up (2026-08-31, reverse geocoding — the gap flagged in
  `06-customer-app.md`'s CUS-1/CUS-4 and `10-web-client.md`'s WEB-2): a
  fourth proxy joins autocomplete/details/route in `app/services/places.py`/
  `app/api/places.py` — `reverse_geocode(lat, lng) -> str | None` calls
  Google's classic Geocoding API
  (`https://maps.googleapis.com/maps/api/geocode/json`) and returns the
  first result's `formatted_address`. New endpoint: `GET
  /v1/places/geocode?lat=&lng=` -> `{"address": "..."}`, auth-required, same
  as autocomplete/details/route (`CurrentUser` dependency).

  Design choice (the task note asked for judgment here): `reverse_geocode`
  sits with `place_details` on the 503-on-failure side of the line — there
  is nothing sensible to fake for a specific coordinate's address the way an
  empty autocomplete list is a fine no-op. Unlike `place_details`, though,
  the service function itself never raises `HTTPException` — it stays a
  plain `str | None` return, kept directly unit-testable without assembling
  a FastAPI exception in a test; the 503 is raised one layer up, in
  `app/api/places.py`'s `geocode` endpoint, when the service returns `None`
  (no key configured, non-OK Google status, or an empty `results` list).

  Regenerated `openapi.json` (`web-client`'s `client:check` CI job would
  otherwise flag it as stale). 7 new tests in `tests/test_places_api.py`
  (auth-required, no-key 503, a mocked successful Google response, a mocked
  non-OK status, and a mocked OK-status-but-empty-results case — both
  failure shapes 503, matching `place_details`'s convention). Full backend
  suite green (345 passed), ruff clean.

  Still no server-side key: every path above is real and tested, but as of
  this session only ever exercises its no-key 503 fallback branch — no live
  call against a real `google_maps_api_key` has happened, same standing gap
  as autocomplete/details/route.

- [x] **JOB-5 — Create / get / list / cancel endpoints** *(deps: JOB-3, JOB-4)*
  `POST /v1/jobs` (from a quote id) → status `matching`; `GET /v1/jobs/{id}`; `GET /v1/jobs?role=` history with pagination; `POST /v1/jobs/{id}/cancel` enforcing JOB-3 rules. Job stores the pricing/commission config snapshot.
  *AC: customer can only see own jobs, driver only assigned ones; snapshot present on created jobs.*

- [x] **JOB-6 — Status transition endpoint (driver)** *(deps: JOB-3)*
  `POST /v1/jobs/{id}/status` — driver advances the machine; validates the caller is the assigned driver.
  *AC: wrong-driver and wrong-order transitions return 409/403; happy path covered by an integration test through all states.*
