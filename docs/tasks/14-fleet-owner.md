# 14 — Fleet owner (FLT) · Phase 6

New role: owners of multiple grúas who assign drivers to trucks and settle one consolidated commission balance. Backend foundations first (FLT-1/2), then the owner-facing screens (FLT-3/4/5 — the frames in `docs/design/screen-references.md`).

- [x] **FLT-1 — Fleet owner role + fleets model** *(deps: AUTH-1, AUTH-5)*
  Add `fleet_owner` to the role enum (already present since AUTH-1) and a `fleets` table (owner user_id); wire the pre-existing `trucks.fleet_id` (nullable since AUTH-5) to it. A truck can exist without a driver; independent drivers keep working with no fleet.
  *AC: fleet CRUD works; dispatch capacity filtering (already reading `trucks`) is unaffected for independent drivers.*
  Built: `fleets` table (migration 0007) + FK/index finally added on the pre-existing `trucks.fleet_id`. `POST /v1/fleets/me` creates the caller's fleet and flips role -> fleet_owner (409 if they already own one, mirrors AUTH-5's register flow); `GET /v1/fleets/me` returns it with its trucks; `POST`/`DELETE /v1/fleets/me/trucks/{truck_id}` attach/detach (409 if the truck already belongs to a fleet, 404 otherwise). Judgment call: real driver-consent for joining a fleet is FLT-4 (not built yet, it's a later Flutter-facing task with an invite flow) — for now any truck with `fleet_id is None` can be claimed by any fleet owner, same "unclaimed resource" gate as AUTH-5's plate uniqueness. `app/services/dispatch.py` never reads `fleet_id`, so independent-driver dispatch is untouched (verified: existing dispatch tests still pass). 8 new tests (`tests/test_fleets_api.py` + a model roundtrip case), full suite green (191 passed).

- [ ] **FLT-2 — Fleet ledger rollup + consolidated settlement** *(deps: FLT-1, LED-1, LED-4)*
  Ledger entries gain fleet attribution via the truck; consolidated balance per fleet owner; settle endpoint accepts a fleet-level payment that clears the constituent driver balances; balance-cap gating (LED-2) evaluates at fleet level for fleet drivers.
  *AC: fleet balance equals sum of member driver balances; one fleet settlement unblocks all capped members.*

- [ ] **FLT-3 — "Mi flota" screen** *(deps: AUTH-4, FLT-1)*
  Fleet owner shell in the Flutter app: per-truck status at a glance (available / on job / unassigned / offline), tap-through to truck detail.
  Design: «Mi flota» (`docs/design/screen-references.md`)
  *AC: statuses reflect live dispatch state for a seeded fleet.*

- [ ] **FLT-4 — Assign driver to truck** *(deps: FLT-3)*
  Link a verified driver to an unassigned truck, or invite a new driver (phone invite → signup lands pre-linked); unassign flow.
  Design: «Asignar conductor a una grúa» (`docs/design/screen-references.md`)
  *AC: assigned driver's offers/dispatch use the truck's capacity; a truck has at most one active driver.*

- [ ] **FLT-5 — Fleet earnings screen** *(deps: FLT-2)*
  Commission accrued per truck, consolidated balance owed, settlement action (cash instructions; Wompi via PAY-3 pattern later).
  Design: «Ganancias de la flota» (`docs/design/screen-references.md`)
  *AC: per-truck numbers reconcile with the ledger; consolidated total matches FLT-2.*
