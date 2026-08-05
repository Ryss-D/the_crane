# Screen references — feature/grua-hailing-app

> **Designs live at:** https://claude.ai/code/artifact/690138b9-1ac4-46eb-99ba-3aa26d444ac8
> Note: the fleet-owner frames map to backlog tasks `FLT-3/4/5` (not FLT-1..3 as below) — `FLT-1/2` are the backend foundations.

Maps each task ID in `docs/tasks/` to its design in `Crane Feature Designs.html` (this project). Paste the relevant line(s) into the task file or the mirrored GitHub issue.

## 06 — Customer mobile flows
- **CUS-5** (delivery + cash payment) → "Entrega y pago en efectivo" frame
- **CUS-6** (saved vehicles) → "Vehículos guardados" frame
- `docs/tasks/08-ratings-history.md` **RAT-3** (trip history) → "Historial" frame

## 07 — Driver mobile flows
- **DRV-1** (home + availability) → "Inicio y disponibilidad" frame
- **DRV-2** (incoming offer sheet) → "Oferta entrante" frame
- **DRV-3** (active job) → "Viaje activo" frame — now shows vehicle/plate + pickup contact, not a rider
- **DRV-4** (cash collection) → "Cobro en efectivo" frame
- **DRV-5** (earnings & balance) → "Ganancias y saldo" frame
- **DRV-6** *(new — not yet in the backlog, propose adding to `07-driver-app.md`)* — "Servicios por período" frame: driver picks Today/Week/Month/Custom and sees a count + list of completed services for that range. Suggested acceptance criteria: range selector updates count, chart, and list together; custom range persists on reopen.

## 11 — Super admin panel
- **ADM-3** (platform config editor) → "Editor de configuración" frame
- **ADM-4** (driver verification queue) → "Cola de verificación" frame
- **ADM-5** (operations view) → "Operaciones en vivo" frame
- **ADM-6** (ledger & settlements) → "Ledger y liquidaciones" frame
- **ADM-0** *(new — propose adding)* — "Resumen de la plataforma" frame: KPI dashboard (trips today, active trucks, avg. assignment time, day's commission) + activity feed. Suggested as the admin's landing route.
- **ADM-7** *(new — propose adding, depends on the fleet-owner role below)* — "Flotas y dueños de grúas" frame: admin-side view of fleet owners, their trucks, and consolidated balance.

## New role: Fleet owner (not in the current plan — proposed addition)
No task file exists yet for this role; suggest a new `docs/tasks/14-fleet-owner.md` (prefix `FLT`) depending on AUTH (new `role=fleet_owner`) and LED (ledger needs a `fleet_owner_id` grouping):
- **FLT-1** — "Mi flota" frame: per-truck status at a glance (available / on job / unassigned / offline)
- **FLT-2** — "Asignar conductor a una grúa" frame: link a verified driver (or invite a new one) to an unassigned truck
- **FLT-3** — "Ganancias de la flota" frame: commission accrued per truck; owner settles one consolidated balance instead of per-driver

**Backend implication:** `driver_profiles` currently has no owner concept — settling "per driver" (§2.5/§9) would need a `fleet_owner_id` on trucks/drivers so the ledger can roll up by owner, and `platform_config`/admin permissions would need a `fleet_owner` role alongside customer/driver/admin.
