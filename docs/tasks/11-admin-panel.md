# 11 — Super admin panel (ADM) · Phase 3 (API) + 4 (UI)

Runtime control of pricing, commission, settlement, and dispatch — plus driver ops. No deploys to change business values.

- [ ] **ADM-1 — Admin SPA scaffold** *(deps: WEB-1 pattern)*
  Vite + React + TS in `admin/`, same generated API client; Firebase login gated on `role=admin`; own subdomain, desktop-first.
  *AC: non-admin login is rejected client- and server-side.*

- [x] **ADM-2 — Admin API router** *(deps: FND-5, JOB-2)*
  `/v1/admin/*` endpoints (config, drivers, jobs, ledger) behind an admin permission dependency; audit context (who) on every mutation.
  *AC: customer/driver tokens get 403 on all admin routes.*

- [ ] **ADM-0 — Platform KPI dashboard (admin landing)** *(deps: ADM-1, ADM-2)*
  Landing route: KPI cards (trips today, active trucks, avg assignment time, day's commission) + recent activity feed.
  Design: «Resumen de la plataforma» (`docs/design/screen-references.md`)
  *AC: KPIs match a seeded dataset; feed shows recent job/driver events newest-first.*

- [ ] **ADM-3 — Platform config editor** *(deps: ADM-1, ADM-2)*
  UI for pricing per vehicle type, **commission mode + rate per type**, **settlement (balance cap, period)**, dispatch tuning (offer TTL, radius). Shows current value + change history; writes bust the Redis cache so changes apply immediately.
  Design: «Editor de configuración» (`docs/design/screen-references.md`)
  *AC: editing commission changes the next completed job's accrual without restart; history lists who/when/previous value.*

- [ ] **ADM-4 — Driver verification queue** *(deps: ADM-2, AUTH-5)*
  Pending drivers list, document viewer, approve/reject with reason, block/unblock.
  Design: «Cola de verificación» (`docs/design/screen-references.md`)
  *AC: approval flips `verified` and the driver can go available; rejection notifies with reason.*

- [ ] **ADM-5 — Operations view** *(deps: ADM-2)*
  Live jobs map/list with status filter; job detail: full transition + offer trail, config snapshot, manual cancel.
  Design: «Operaciones en vivo» (`docs/design/screen-references.md`)
  *AC: an in-flight seeded job appears live; manual cancel follows state-machine rules.*

- [ ] **ADM-6 — Ledger & settlements** *(deps: LED-4)*
  Balances per driver, drill-down to entries, record settlements/adjustments, totals per period (platform revenue).
  Design: «Ledger y liquidaciones» (`docs/design/screen-references.md`)
  *AC: recording a settlement unblocks a capped driver (LED-2) and shows in their app balance.*

- [ ] **ADM-7 — Fleets & owners view** *(deps: ADM-2, FLT-2)* · Phase 6
  Fleet owners list with their trucks, per-truck driver assignment, and consolidated fleet balance.
  Design: «Flotas y dueños de grúas» (`docs/design/screen-references.md`)
  *AC: consolidated balance equals the sum of the fleet's driver ledger balances.*
