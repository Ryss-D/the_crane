# 02 — Auth & accounts (AUTH) · Phase 0–1

Phone-OTP identity via Firebase; profiles and roles live in Postgres.

- [ ] **AUTH-1 — Users model + migration** *(deps: FND-2)*
  `users`: id (uuid), firebase_uid (unique), role (customer|driver|admin), name, phone, email, fcm_token, created_at.
  *AC: migration applies; unique constraint on firebase_uid.*

- [ ] **AUTH-2 — `POST /v1/auth/sync` + `GET/PATCH /v1/me`** *(deps: AUTH-1, FND-5)*
  Sync creates-or-fetches the profile after Firebase signup (default role customer). `/me` returns profile; PATCH updates name/email/fcm_token.
  *AC: idempotent sync (second call returns existing row); tests for both roles.*

- [ ] **AUTH-3 — Flutter phone OTP flow** *(deps: FND-4, FND-1)*
  Screens: phone entry (+57 default) → OTP → profile completion (name) → calls `/auth/sync`. Dio interceptor injects/refreshes the ID token.
  *AC: full signup on dev flavor with a Firebase test number; token refresh survives app restart.*

- [ ] **AUTH-4 — Role-aware routing** *(deps: AUTH-3)*
  go_router guards: unauthenticated → auth stack; customer → customer shell; driver → driver shell; role stored on profile.
  *AC: switching the role in DB lands the user in the other shell on next launch.*

- [ ] **AUTH-5 — Driver registration flow** *(deps: AUTH-4)*
  From settings: "become a driver" — truck info (plate, type, capacity moto/car/both) + document upload (license, truck photo) to object storage; sets role=driver with `verified=false`.
  *AC: `driver_profiles` row created; unverified drivers see a "pending verification" state and cannot go available.*

- [ ] **AUTH-6 — FCM token lifecycle** *(deps: AUTH-3)*
  Register/refresh device token on login and token rotation; clear on logout.
  *AC: backend can push a test notification to a logged-in device.*
