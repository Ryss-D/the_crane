# Architecture Decisions (ADR log)

Each entry: context → decision → consequences. Dates are when the decision was locked.

## ADR-1 — FastAPI backend with Firebase for identity/push only (2026-08-04)
**Context:** Needed fast MVP delivery, real geo-queries, and complex dispatch logic. Full-Firebase (Firestore) couldn't express "nearest available truck with capacity X", and full-custom auth meant handling OTP flows.
**Decision:** Custom FastAPI + Postgres backend; Firebase kept strictly for phone-OTP identity (backend verifies ID tokens) and FCM push.
**Consequences:** All domain logic and money data under our control and testable; the only Firebase lock-in is auth, which is swappable (the backend just verifies a JWT). Two systems to run instead of one.

## ADR-2 — PostGIS for geo, Redis for live positions (2026-08-04)
**Context:** Dispatch needs distance-ordered searches; driver positions update every ~5s and are worthless minutes later.
**Decision:** PostGIS on job/driver records for durable geo; Redis geo-sets for live availability; Postgres stores position snapshots only at job transitions (audit/disputes).
**Consequences:** Postgres write volume stays tiny; dispatch queries are cheap; Redis is disposable state — losing it means drivers re-appear as they stream positions.

## ADR-3 — Single Flutter app with role switch, not two apps (2026-08-04)
**Context:** Uber ships separate rider/driver apps; we're pre-launch in one city.
**Decision:** One codebase, one store listing; UI branches by role (customer / driver / fleet-owner) after login.
**Consequences:** Half the release surface at MVP; revisit a split only if driver-app background-location review friction or app size demands it.

## ADR-4 — React (not Vue) for web client and admin panel (2026-08-04)
**Context:** Two SPAs needed — a no-install customer flow and an internal admin panel. Vue was considered.
**Decision:** Vite + React + TypeScript for both, sharing the generated API client.
**Consequences:** Best-in-class maps binding (@vis.gl/react-google-maps), TanStack Query, deepest hiring pool; one mental model across both web surfaces.

## ADR-5 — FastAPI OpenAPI spec as the API contract (2026-08-04)
**Context:** Three frontends against one API risks drift.
**Decision:** TypeScript clients for web/admin are generated from the backend's OpenAPI schema; CI checks spec/client sync.
**Consequences:** Backend types are the single source of truth; breaking changes surface at build time, not runtime.

## ADR-6 — WebSockets foreground, FCM background, REST rehydration (2026-08-04)
**Context:** Live tracking needs sub-5s updates; mobile apps get killed; push alone is unreliable for streams.
**Decision:** WS for foregrounded apps (locations up, events down, Redis pub/sub across workers); FCM data messages for offers/status when backgrounded; reopening rehydrates via `GET /jobs/{id}`.
**Consequences:** No single channel is trusted to be always-on; every event is reconstructible from Postgres.

## ADR-7 — Cash MVP with a day-one ledger; commission charged to drivers (2026-08-04)
**Context:** Tow customers in Colombia largely pay cash; card compliance would block launch. Monetization is a per-service fee charged to the driver.
**Decision:** MVP settles fares in cash; every completed job writes a `driver_ledger` debit (driver owes platform commission). Payments/ledger tables exist from Phase 1 behind a `PaymentProvider` interface whose first implementation is `cash`.
**Consequences:** Monetized from the first completed job; going digital later flips a provider, not the architecture. Requires balance-cap gating to control cash-collection risk.

## ADR-8 — Wompi first, commission-first rollout; MercadoPago deferred (2026-08-04)
**Context:** Medellín launch. Wompi (Bancolombia) has PSE/Nequi/cards with lower fees and a simpler API; MercadoPago has multi-country reach and marketplace split payments.
**Decision:** Wompi as first gateway. First digital integration is drivers paying their commission balance (Nequi/PSE) — smaller and lower-risk than customer checkout. Webhooks (signature-verified, idempotent) are the source of truth; card data never touches our servers.
**Consequences:** Fastest compliant path in Colombia; MercadoPago remains a config-level addition via the provider interface if we go multi-country.

## ADR-9 — Runtime `platform_config` instead of hardcoded business values (2026-08-04)
**Context:** Fares, commission rate/mode, settlement caps, and dispatch tuning will be tweaked constantly at launch.
**Decision:** Versioned key/value config in Postgres, cached in Redis with bust-on-write, edited from the super admin panel, fully audit-logged. **Jobs snapshot the config they were priced under.**
**Consequences:** Operators tune the business without deploys; historical jobs/ledger entries are immune to config changes; every change is attributable.

## ADR-10 — Sequential nearest-first dispatch with offer audit (2026-08-04)
**Context:** Broadcast-to-many dispatch is complex (races, retractions) and unnecessary at launch supply.
**Decision:** Offer to nearest fitting driver with a config TTL; on reject/timeout, next; widen radius once; `no_drivers` after. Every offer recorded in `job_offers`; accept race resolved with row locks.
**Consequences:** Simple, debuggable, fair; measurable via the offer trail. Broadcast is a contained future change inside the dispatch service.

## ADR-11 — Trucks as a first-class table from day one (2026-08-04)
**Context:** The fleet-owner role (Phase 6) needs trucks that exist without drivers; naive MVP would put truck fields on `driver_profiles`.
**Decision:** `trucks` (plate, type, capacity, nullable driver_id, nullable fleet_id) is its own table from the first migration; dispatch capacity filtering reads trucks.
**Consequences:** Phase 6 adds a `fleets` table and links — no data migration, no dispatch changes for independent drivers.

## ADR-12 — Web client is customer-only; drivers stay native (2026-08-04)
**Context:** A stranded customer shouldn't need an app download, but driver work needs background GPS and reliable push.
**Decision:** React web app covers request/track/pay/rate + a public tokenized share-track page; driver features are exclusively in the Flutter app.
**Consequences:** Web scope stays small; no fighting mobile-web background limitations; share-track link doubles as the app's trip-share feature.
