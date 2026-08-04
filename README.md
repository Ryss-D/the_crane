# The Crane 🏗️

Uber-style dispatch platform for grúas (tow trucks) hauling motos and cars. Launch market: **Medellín, Colombia**.

## Workspaces

| Path | What | Stack |
|---|---|---|
| `/` (root) | Mobile app — customer + driver, role switch | Flutter, Riverpod, go_router, Google Maps |
| `backend/` | API — dispatch, pricing, jobs, ledger, payments | FastAPI, PostgreSQL/PostGIS, Redis, Firebase Admin |
| `web-client/` | Customer web app — request/track without installing | React (Vite + TS), Firebase Auth web |
| `admin/` | Super admin panel — config, drivers, ops, ledger | React (Vite + TS) |

## Docs

- **[docs/PLAN.md](docs/PLAN.md)** — full product & technical plan (architecture, data model, state machine, dispatch, payments/Wompi, phases)
- **[docs/tasks/](docs/tasks/README.md)** — backlog split per feature with task IDs, dependencies, and acceptance criteria

## Key decisions

- Firebase = auth (phone OTP) + push only; all domain data in Postgres, geo queries via PostGIS, live locations in Redis
- Cash settlement for MVP; **driver commission per completed service**, accrued in a ledger from day one; Wompi (PSE/Nequi/cards) in Phase 5
- Pricing, commission, settlement, and dispatch parameters are **runtime-configurable** via the super admin panel (`platform_config`) — never hardcoded
