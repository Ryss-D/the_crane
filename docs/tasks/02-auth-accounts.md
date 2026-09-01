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

  Follow-up (2026-08-31): real document upload, closing the one deliberately-scoped-out piece above -- `BecomeDriverScreen`'s license/truck-photo fields were plain hand-typed URL text fields; they're now an `image_picker` gallery-chooser flow that uploads to Firebase Storage (project `FND-1`/`the-crane-c6b86`, same one already wired for Auth/Messaging in `lib/main.dart` -- Storage is just a new SDK on it, no new project). Backend needed zero changes, as expected: `license_url`/`truck_photo_url` were already opaque `str | None` (`backend/app/schemas/driver.py`) and don't care where the string came from.

  Built: `DocumentUploadRepository` (`lib/core/storage/document_upload_repository.dart`, real `FirebaseDocumentUploadRepository` + `FakeDocumentUploadRepository`) uploads to `driver-documents/{driverUserId}/{kind}<ext>` and returns the download URL. `DocumentImagePicker` (`lib/core/storage/document_image_picker.dart`, real `ImagePickerDocumentPicker` + `FakeDocumentImagePicker`) wraps `image_picker`'s gallery chooser the same way `LocationSource` already wraps `geolocator` -- a small interface seam rather than `image_picker_platform_interface`'s own heavier test-fake convention, kept consistent with this codebase's existing hardware-adjacent pattern. Both are wired into `AppDependencies`/`main.dart`/`test_dependencies.dart` exactly like every other repository here, picked by `Env.useFakeBackend`.

  Design call -- upload timing: pick-and-upload-immediately (with a visible per-document thumbnail + spinner-over-thumbnail + inline retry-able error), not upload-on-submit. Reasoning: the two documents are genuinely independent of the rest of the form (plate/truck type/capacity), so there's no reason to make the driver wait through a form-submit spinner for two uploads that could have started the moment each photo was picked; failing early and inline (with the thumbnail still visible so the driver can see what they picked) is also a smaller, easier-to-reason-about failure surface than folding upload errors into the same generic "registration failed" banner submit already has. Both documents stay fully optional per the AC -- a picked-but-failed-to-upload document is simply left out of the request (`licenseUrl`/`truckPhotoUrl` stay `null`), never blocks submit.

  `become_driver_flow_widget_test.dart` was reworked: the old two `TextField`s are gone; three new tests cover pick→thumbnail→uploaded-status→real-URL-sent-to-`registerDriver`, upload-failure→inline-error→submit-still-succeeds-without-that-document, and picker-cancel→no-state-change (427 → 430 passing). `FakeDocumentImagePicker` writes a real (but tiny, generated, non-golden-asset) PNG to a temp file *synchronously* -- widget tests run inside a FakeAsync zone (see this file's own pre-existing FLT-4-invite-test comments on the same gotcha) where real async dart:io I/O never resolves without `tester.runAsync`; a sync write sidesteps that.

  Not done / still open: no live pass against a real Firebase Storage bucket or a real device's camera/gallery -- same standing gap as every other "verified against the fakes only" item in this file (AUTH-3/4, the rest of AUTH-5). The box above stays unchecked for that reason (plus AUTH-5's own prior real-backend-end-to-end gap, still open too) -- this follow-up only closes the "document upload is out of scope" caveat, not the wider live-verification gap.

  Real gap caught and fixed during review: `ios/Runner/Info.plist` had no
  `NSPhotoLibraryUsageDescription` key -- unlike a missing location key
  (soft permission-denied), iOS hard-crashes the app the instant
  `image_picker`'s gallery chooser requests photo-library access without
  one. Added it (gallery-only picker, so `NSCameraUsageDescription` isn't
  needed). Android needed no manifest change: `image_picker_android`'s own
  bundled manifest declares no storage permission at all -- it relies
  entirely on the modern system Photo Picker intent, confirmed by reading
  the plugin's manifest directly rather than assuming. Two more manual
  steps for whoever does the live pass: (1) Firebase Storage's security
  rules need configuring in the Firebase Console (default rules deny all
  reads/writes) before a real upload will succeed, same class of
  Console-side step as everything else FND-1 already tracks; (2) the
  Storage bucket itself needs enabling on the Firebase project if it isn't
  already (Storage isn't auto-enabled the way Auth/Messaging are).

- [ ] **AUTH-6 — FCM token lifecycle** *(deps: AUTH-3)*
  Register/refresh device token on login and token rotation; clear on logout.
  *AC: backend can push a test notification to a logged-in device.*
  Built: `PushTokenGateway` (real + fake), wired into `AuthCubit` — registers the token after sign-in/profile completion, re-sends it on OS-level token refresh (only while authenticated), clears it via `PATCH /v1/me` before the Firebase session itself closes on sign-out. Verified against the fake gateway (2 dedicated `AuthCubit` unit tests, 49 total passing). Not yet verified: an actual push notification delivered to a real device via FCM — needs that manual pass before checking this off.
