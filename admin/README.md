# The Crane — Super Admin Panel (React)

Internal, desktop-first SPA behind the `admin` role, deployed on its own subdomain. See `docs/PLAN.md` §4.4 and `docs/tasks/11-admin-panel.md`.

## Sections
- **Platform config** — pricing, commission mode/rate per vehicle type, settlement policy (balance cap, period), dispatch tuning. Edits apply at runtime (Redis cache bust) and are audit-logged.
- **Drivers** — verification queue (document review), block/unblock, balances.
- **Operations** — live jobs map/list, job event + offer trail, manual cancel.
- **Ledger** — commission balances, settlements, adjustments.

Same stack and generated API client as `web-client/`. Scaffolded in task `ADM-1`.
