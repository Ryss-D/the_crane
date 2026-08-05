# 14 — Fleet owner (FLT) · Phase 6

New role: owners of multiple grúas who assign drivers to trucks and settle one consolidated commission balance. Backend foundations first (FLT-1/2), then the owner-facing screens (FLT-3/4/5 — the frames in `docs/design/screen-references.md`).

- [ ] **FLT-1 — Fleet owner role + fleet/truck data model** *(deps: AUTH-1, AUTH-5)*
  Add `fleet_owner` to the role enum. New tables: `fleets` (owner user_id) and `trucks` (plate, type, capacity, fleet_id nullable, active driver_id nullable) — migrating truck fields off `driver_profiles` so a truck can exist without a driver. Independent drivers keep working: their truck simply has no fleet.
  *AC: migration preserves existing driver/truck data; dispatch capacity filtering reads from `trucks`.*

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
