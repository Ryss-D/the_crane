# The Crane — Task Backlog

The plan (`docs/PLAN.md`) split into features and tasks. One file per feature; each task has an ID, dependencies, and acceptance criteria. Check tasks off here as they land (or mirror them to GitHub issues — IDs are stable for that).

## Workspaces

| Path | What | Status |
|---|---|---|
| `/` (root) | Flutter mobile app (customer + driver + fleet-owner) | most feature screens built and tested against fakes; map/Places/polyline UI blocked on FND-6 (Google Maps keys), and several flows (auth, offer distance/commission wiring, driver background location) are code-complete but not yet run live against the real Firebase project/a device — see per-task notes in `02-auth-accounts.md`, `06-customer-app.md`, `07-driver-app.md`, `05-realtime-tracking.md` |
| `backend/` | FastAPI API | jobs/dispatch/tracking/ledger/ratings/admin/fleets all implemented (90%+ pytest coverage); payments beyond cash (Wompi, `12-payments-wompi.md`) not started; no deploy target yet (`13-devops.md`) |
| `web-client/` | React customer web app (`web/` is Flutter's web target) | scaffold, auth, request flow, live tracking, and public share-track page built (`10-web-client.md`); Maps/Places still stubbed pending FND-6; not yet deployed (WEB-5) |
| `admin/` | React super admin panel | config, drivers, ops, ledger, and fleets views built (`11-admin-panel.md`); not yet deployed (OPS-5) |

## Features → phases

| # | Feature file | ID prefix | Phase | Depends on |
|---|---|---|---|---|
| 01 | [Foundations](01-foundations.md) | FND | 0 | — |
| 02 | [Auth & accounts](02-auth-accounts.md) | AUTH | 0–1 | FND |
| 03 | [Jobs, quotes & pricing](03-jobs-pricing.md) | JOB | 1 | FND, AUTH |
| 04 | [Dispatch & matching](04-dispatch.md) | DSP | 1 | JOB |
| 05 | [Realtime & tracking](05-realtime-tracking.md) | TRK | 2 | JOB, DSP |
| 06 | [Customer mobile flows](06-customer-app.md) | CUS | 1–2 | AUTH, JOB |
| 07 | [Driver mobile flows](07-driver-app.md) | DRV | 1–2 | AUTH, DSP, TRK |
| 08 | [Ratings & history](08-ratings-history.md) | RAT | 3 | JOB |
| 09 | [Ledger & commission](09-ledger-commission.md) | LED | 1, 3 | JOB |
| 10 | [Web client](10-web-client.md) | WEB | 4 | JOB, TRK |
| 11 | [Super admin panel](11-admin-panel.md) | ADM | 3–4 | LED, JOB |
| 12 | [Payments (Wompi)](12-payments-wompi.md) | PAY | 5 | LED |
| 13 | [DevOps & CI](13-devops.md) | OPS | 0+ | — |
| 14 | [Fleet owner](14-fleet-owner.md) | FLT | 6 | AUTH, LED |

## Conventions

- **Status:** unchecked `[ ]` = todo, `[x]` = done. Add `(WIP @name)` while in progress.
- **Branches:** `feature/<id>-<slug>` off `dev` (e.g. `feature/job-3-state-machine`), PR into `dev`.
- **Definition of done:** acceptance criteria met, tests for backend logic, `flutter analyze` / `ruff` clean, reviewed.
- Config values (fares, commission, dispatch tuning) are **never hardcoded** — they live in `platform_config` (see JOB-2, ADM-3).
- **Designs:** screens link to frames in the [design artifact](https://claude.ai/code/artifact/690138b9-1ac4-46eb-99ba-3aa26d444ac8); mapping in `docs/design/screen-references.md`.
