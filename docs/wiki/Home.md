# The Crane 🏗️

Uber-style dispatch platform for grúas (tow trucks) hauling motos and cars. Launch market: **Medellín, Colombia**.

| Page | What's there |
|---|---|
| [[Architecture]] | System diagram, components, data model, job state machine |
| [[Technology Stack]] | Every technology used, per workspace, and why |
| [[Architecture Decisions]] | ADR log — the reasoning behind each major decision |

## Quick facts

- **Clients:** Flutter mobile app (customer / driver / fleet-owner role switch), React customer web app (no-install), React super admin panel
- **Backend:** FastAPI + PostgreSQL/PostGIS + Redis; Firebase for auth (phone OTP) and push only
- **Monetization:** platform commission per completed service, charged to the driver via a ledger; cash settlement at MVP, Wompi (PSE/Nequi/cards) later
- **Everything operational is runtime-configurable** from the admin panel (`platform_config`): fares, commission, settlement policy, dispatch tuning

## Where the work lives

- Plan: [`docs/PLAN.md`](https://github.com/Ryss-D/the_crane/blob/feature/grua-hailing-app/docs/PLAN.md)
- Backlog: [`docs/tasks/`](https://github.com/Ryss-D/the_crane/blob/feature/grua-hailing-app/docs/tasks/README.md) → mirrored as [issues](https://github.com/Ryss-D/the_crane/issues)
- Board: [The Crane — Roadmap](https://github.com/users/Ryss-D/projects/3) (group by Phase or Feature)
- Designs: [design artifact](https://claude.ai/code/artifact/690138b9-1ac4-46eb-99ba-3aa26d444ac8) · frame map in [`docs/design/screen-references.md`](https://github.com/Ryss-D/the_crane/blob/feature/grua-hailing-app/docs/design/screen-references.md)
