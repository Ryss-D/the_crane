# The Crane — Customer Web App (React)

> Note: this lives in `web-client/` because `web/` is the Flutter web build target.

No-install customer flow: request and track a grúa from the browser. Customer role only — drivers use the Flutter app. See `docs/PLAN.md` §4 and `docs/tasks/10-web-client.md`.

## Stack
- Vite + React + TypeScript, Tailwind (mobile-first)
- TanStack Query + Zustand
- Firebase Auth web (phone OTP — same accounts as the mobile app)
- `@vis.gl/react-google-maps`, Places Autocomplete
- API client generated from the FastAPI OpenAPI spec (`openapi-typescript`)

Includes the public share-track page (`/t/{job_token}`) — read-only live tow map, no login.

Scaffolded in task `WEB-1`.
