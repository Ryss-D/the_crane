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

- [x] **ADM-6 — Ledger & settlements** *(deps: LED-4)*
  Balances per driver, drill-down to entries, record settlements/adjustments, totals per period (platform revenue).
  Design: «Ledger y liquidaciones» (`docs/design/screen-references.md`)
  *AC: recording a settlement unblocks a capped driver (LED-2) and shows in their app balance.*
  Backend gained `GET /v1/admin/ledger/{driver_id}/entries` (drill-down) — the original `/ledger` endpoint only ever listed balances, never individual entries. The "capped" badge reads `balance_cap` from the same platform-config query `ConfigPage` uses, not a per-row field (the backend has no such field — it's one global value).

- [ ] **ADM-7 — Fleets & owners view** *(deps: ADM-2, FLT-2)* · Phase 6
  Fleet owners list with their trucks, per-truck driver assignment, and consolidated fleet balance.
  Design: «Flotas y dueños de grúas» (`docs/design/screen-references.md`)
  *AC: consolidated balance equals the sum of the fleet's driver ledger balances.*
