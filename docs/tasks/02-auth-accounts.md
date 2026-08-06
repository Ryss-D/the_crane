# 02 — Auth & accounts (AUTH) · Phase 0–1

Phone-OTP identity via Firebase; profiles and roles live in Postgres.

- [x] **AUTH-1 — Users model + migration** *(deps: FND-2)*
  `users`: id (uuid), firebase_uid (unique), role (customer|driver|admin), name, phone, email, fcm_token, created_at.
  *AC: migration applies; unique constraint on firebase_uid.*

- [x] **AUTH-2 — `POST /v1/auth/sync` + `GET/PATCH /v1/me`** *(deps: AUTH-1, FND-5)*
  Sync creates-or-fetches the profile after Firebase signup (default role customer). `/me` returns profile; PATCH updates name/email/fcm_token.
  *AC: idempotent sync (second call returns existing row); tests for both roles.*

- [ ] **AUTH-3 — Flutter phone OTP flow** *(deps: FND-4, FND-1)*
  Screens: phone entry (+57 default) → OTP → profile completion (name) → calls `/auth/sync`. Dio interceptor injects/refreshes the ID token.
  *AC: full signup on dev flavor with a Firebase test number; token refresh survives app restart.*
  Built: real phone-entry → OTP → sync → profile-completion screens, `PhoneAuthGateway`/`AuthRepository` seams (real + fake), `AuthCubit` driving the whole flow, `AuthInterceptor` already injects the real ID token. Verified against the fake gateway (47 tests, incl. dedicated `AuthCubit` unit tests) and a real iOS build. Not yet verified: an actual run against the live project's test number (`+57 300 0000000` / `123456`) with `USE_FAKE_BACKEND=false` end to end on a device/simulator — needs that manual pass before checking this off.

- [ ] **AUTH-4 — Role-aware routing** *(deps: AUTH-3)*
  go_router guards: unauthenticated → auth stack; customer → customer shell; driver → driver shell; role stored on profile.
  *AC: switching the role in DB lands the user in the other shell on next launch.*
  Built: `routerRedirect` is now genuinely reactive to `AuthCubit`'s state (bridged into go_router's `refreshListenable`), routes by the synced profile's `role`, and a driver-role fake repository test confirms it lands on the driver shell. Same "needs a live end-to-end pass" caveat as AUTH-3 — not yet checked off pending that.

- [ ] **AUTH-5 — Driver registration flow** *(deps: AUTH-4)*
  From settings: "become a driver" — truck info (plate, type, capacity moto/car/both) + document upload (license, truck photo) to object storage; sets role=driver with `verified=false`. Truck data goes in a separate `trucks` table (fleet_id nullable, driver_id nullable) from the start — not columns on `driver_profiles` — so FLT-1 later attaches fleets without a migration.
  *AC: `driver_profiles` + `trucks` rows created; unverified drivers see a "pending verification" state and cannot go available.*
  Backend done: `POST /v1/drivers/me/register` creates both rows, flips role, blocks unverified from going available.
  Built (Flutter half): new `SettingsScreen` reachable from the customer home app bar → `BecomeDriverScreen` (plate, truck type, capacity, optional license/truck-photo URLs — document *upload* itself is still out of scope, plain string URLs only, matching the backend schema). `DriversRepository.registerDriver` added (real dio + fake). On success, `AuthCubit.refreshUser()` (new) re-syncs the profile and `routerRedirect` picks up the new role — fixed a real gap there too: the redirect previously only fired when leaving the auth-stack routes, so a role flip while already sitting inside the customer shell (exactly this flow) was silently ignored; it now also bounces out of a shell that no longer matches the current role. Also fixed a pre-existing bug: `DriverProfile` had flat `truckPlate`/`truckType`/`capacity` fields that don't match the real backend's nested `truck` object (`DriverProfileRead.truck`), so they silently parsed to null against a real server — same class of bug `AppUser.name`/`phone` hit earlier. `DriverProfile.truck` is now a nested `Truck?` (with `Truck.fleetId` added to fully match `TruckRead`), and the one fake/dev call site was updated; model + fake + widget tests cover the fix and the full become-driver flow. Verified against the fakes (55 tests).

  Correction: a second, separate bug would also have broken this against the real backend -- the backend's `TruckType` enum used `moto_only`/`flatbed`/`standard` while Flutter's has always used `moto_only`/`car`/`flatbed`, so picking "car" in `BecomeDriverScreen` would have sent a value the backend's enum validation rejects (422). Fixed by aligning the backend on `car` (see the JOB-5 driver-summary commit) -- both sides now speak the same three values. Still not yet verified: a real run against the live backend end to end.

- [ ] **AUTH-6 — FCM token lifecycle** *(deps: AUTH-3)*
  Register/refresh device token on login and token rotation; clear on logout.
  *AC: backend can push a test notification to a logged-in device.*
  Built: `PushTokenGateway` (real + fake), wired into `AuthCubit` — registers the token after sign-in/profile completion, re-sends it on OS-level token refresh (only while authenticated), clears it via `PATCH /v1/me` before the Firebase session itself closes on sign-out. Verified against the fake gateway (2 dedicated `AuthCubit` unit tests, 49 total passing). Not yet verified: an actual push notification delivered to a real device via FCM — needs that manual pass before checking this off.
