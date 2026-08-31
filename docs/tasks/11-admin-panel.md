# 11 — Super admin panel (ADM) · Phase 3 (API) + 4 (UI)

Runtime control of pricing, commission, settlement, and dispatch — plus driver ops. No deploys to change business values.

- [x] **ADM-1 — Admin SPA scaffold** *(deps: WEB-1 pattern)*
  Vite + React + TS in `admin/`, same generated API client; Firebase login gated on `role=admin`; own subdomain, desktop-first.
  *AC: non-admin login is rejected client- and server-side.*
  Note: real Firebase email/password auth is wired (`src/auth/firebaseAuth.ts`) and selected automatically once `VITE_USE_MOCKS=false` — defaults to FakeAuth until then. Still needed: enable Email/Password sign-in in the console + create an admin user, and the deploy subdomain (OPS-5).

- [x] **ADM-2 — Admin API router** *(deps: FND-5, JOB-2)*
  `/v1/admin/*` endpoints (config, drivers, jobs, ledger) behind an admin permission dependency; audit context (who) on every mutation.
  *AC: customer/driver tokens get 403 on all admin routes.*

- [x] **ADM-0 — Platform KPI dashboard (admin landing)** *(deps: ADM-1, ADM-2)*
  Landing route: KPI cards (trips today, active trucks, avg assignment time, day's commission) + recent activity feed.
  Design: «Resumen de la plataforma» (`docs/design/screen-references.md`)
  *AC: KPIs match a seeded dataset; feed shows recent job/driver events newest-first.*

- [x] **ADM-3 — Platform config editor** *(deps: ADM-1, ADM-2)*
  UI for pricing per vehicle type, **commission mode + rate per type**, **settlement (balance cap, period)**, dispatch tuning (offer TTL, radius). Shows current value + change history; writes bust the Redis cache so changes apply immediately.
  Design: «Editor de configuración» (`docs/design/screen-references.md`)
  *AC: editing commission changes the next completed job's accrual without restart; history lists who/when/previous value.*

- [x] **ADM-4 — Driver verification queue** *(deps: ADM-2, AUTH-5)*
  Pending drivers list, document viewer, approve/reject with reason, block/unblock.
  Design: «Cola de verificación» (`docs/design/screen-references.md`)
  *AC: approval flips `verified` and the driver can go available; rejection notifies with reason.*
  Document viewer shows the real `license_url`/`truck_photo_url` (added to `AdminDriverRead`) as links, not a fake documents list.

- [x] **ADM-5 — Operations view** *(deps: ADM-2)*
  Live jobs map/list with status filter; job detail: full transition + offer trail, config snapshot, manual cancel.
  Design: «Operaciones en vivo» (`docs/design/screen-references.md`)
  *AC: an in-flight seeded job appears live; manual cancel follows state-machine rules.*
  Fixed: backend now joins `customer_name`/`customer_phone`/`driver_name` into `AdminJobListItem`/`JobAdminDetail`/`JobOfferRead` (batched, not N+1) so Operations, the KPI feed, and the offer trail show real names instead of raw UUIDs. Admin's frontend types/mock/pages were also fully realigned against the real backend contract in the same pass (Driver, DriverLedgerSummary, LedgerEntry shapes; pagination envelopes; document viewer now shows real license/truck-photo links).

  Correction (2026-08-31): this box was checked without ever actually
  building the "map" half of "Live jobs map/list" — `OperationsPage.tsx`
  was list-only, with no note flagging the gap. Fixed now: a new
  `OperationsMap` (`@vis.gl/react-google-maps`, same library and pattern
  `web-client`'s tracking/request maps just adopted — mirrors
  `TrackingMap`'s structure, plain legacy `Marker` since `AdvancedMarker`
  needs a Cloud Console Map ID that doesn't exist yet) shows one pin per
  visible (post status-filter) job at its pickup point; clicking a pin
  navigates to that job's detail, same as its row. `VITE_GOOGLE_MAPS_API_KEY`
  was already present in `admin/.env.local` (the Web key set up in FND-6) —
  no new key needed.

  Real gap surfaced and fixed along the way: `admin/src/api/types.ts`'s
  `Job` interface never declared `pickup_lat`/`pickup_lng`/`dropoff_lat`/
  `dropoff_lng` at all, even though the real backend's `AdminJobListItem`
  (`backend/app/schemas/admin.py`) always returns them — the exact same
  class of stale-type bug the web-client fork found in its own `types.ts`
  independently. Fixed (types + `MockApi`'s 15 seeded jobs, given real
  Medellín-neighborhood coordinates so the map has something real to
  show under mocks); `HttpApi.getJobs` needed no change, it already just
  deserializes whatever the backend sends.

  Genuine, separate limitation: **no live driver position on this map.**
  Checked directly — `GET /v1/admin/jobs/{id}` only returns historical
  `location_snapshots` (recorded at status transitions, `DriverLocationSnapshotRead`)
  for one job's own detail view; there is no admin-facing endpoint or WS
  channel exposing a driver's *current* position across many jobs for a
  list view the way the customer-facing tracking pages get one over their
  job's own WebSocket channel. Pickup-only pins are what the real data
  actually supports today — a live fleet-position overlay would need a new
  backend capability, not attempted here.

  Tests: 3 new (`OperationsPage.test.tsx`) — pin count matches the seeded
  jobs and carries real coordinates, pin count follows the status filter,
  clicking a pin navigates to that job's detail. `@vis.gl/react-google-maps`
  mocked wholesale in `admin/src/test/setup.tsx` (renamed from `.ts`,
  mirroring `web-client`'s identical mock, adapted to a clickable `<button>`
  marker stand-in so the pin-click test is real). Full suite green (62
  passed, up from 55), lint clean (5 pre-existing unrelated errors
  untouched), build clean. Not verified: a live pass against the real
  deployed key/domain/backend.

- [x] **ADM-6 — Ledger & settlements** *(deps: LED-4)*
  Balances per driver, drill-down to entries, record settlements/adjustments, totals per period (platform revenue).
  Design: «Ledger y liquidaciones» (`docs/design/screen-references.md`)
  *AC: recording a settlement unblocks a capped driver (LED-2) and shows in their app balance.*
  Backend gained `GET /v1/admin/ledger/{driver_id}/entries` (drill-down) — the original `/ledger` endpoint only ever listed balances, never individual entries. The "capped" badge reads `balance_cap` from the same platform-config query `ConfigPage` uses, not a per-row field (the backend has no such field — it's one global value).

- [ ] **ADM-7 — Fleets & owners view** *(deps: ADM-2, FLT-2)* · Phase 6
  Fleet owners list with their trucks, per-truck driver assignment, and consolidated fleet balance.
  Design: «Flotas y dueños de grúas» (`docs/design/screen-references.md`)
  *AC: consolidated balance equals the sum of the fleet's driver ledger balances.*
  Built: `FleetsPage` (`admin/src/features/fleets/`) — table of every fleet
  (owner, name, truck count, consolidated owed balance) via `GET
  /v1/admin/fleets`; clicking a row drills into its member-balance breakdown
  (`GET /v1/admin/fleets/{id}/balance`); a "Liquidar flota" action posts to
  `POST /v1/admin/fleets/{id}/settle` (amount + optional note) and shows the
  resulting per-driver apportionment as confirmation, then refreshes both the
  list and the drill-down. Wired into the sidebar nav and router alongside
  ADM-1..6. `CraneAdminApi` gained `getFleets`/`getFleetBalance`/
  `settleFleet`; `MockApi` seeds 2 fleets (3 and 2 member drivers, reusing
  existing seed drivers' ledger balances so the consolidated total is
  mechanically the sum of its members, satisfying the AC directly — verified
  by test) plus a largest-remainder `apportion()` mirroring the backend's.
  3 new tests in `FleetsPage.test.tsx` (list totals, member drill-down,
  settle-and-refresh), full admin suite green (lint/test/build all clean).
  Not built: per-truck driver assignment — there is no admin-facing endpoint
  for it (only `GET /fleets`, `GET /fleets/{id}/balance`, `POST
  /fleets/{id}/settle` exist in `backend/app/api/admin.py`); assigning a
  driver to a truck is owner-facing (`POST/DELETE /v1/fleets/me/trucks/
  {truck_id}` from FLT-1) and slated for FLT-4, not this admin task. Leaving
  the box unchecked since that part of the original bullet's scope is
  genuinely not covered yet.

  Update (2026-08-31): FLT-4 (`docs/tasks/14-fleet-owner.md`) is done now —
  owner-facing driver-to-truck assignment (invite flow) exists and works.
  Still leaving this box unchecked: that's a deliberate scope split (owners
  assign their own drivers; admins don't need a duplicate control for the
  same action), not a gap this task should fill by adding a redundant
  admin-side assignment UI — but if the product intent behind ADM-7's
  original wording was specifically an *admin override* capability (assign/
  reassign regardless of owner action, e.g. for support cases), that's
  still genuinely unbuilt. Flagging the ambiguity rather than resolving it
  unilaterally.
