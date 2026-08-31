# 05 — Realtime & tracking (TRK) · Phase 2

WebSocket layer for live positions and job events; FCM covers backgrounded apps.

- [x] **TRK-1 — Authed WebSocket endpoint** *(deps: FND-5)*
  `WS /v1/ws`: token auth on connect, channel routing (driver location up; job events down), Redis pub/sub between API workers, heartbeat + stale-connection cleanup.
  *AC: two clients on different workers receive each other's job events; dead sockets pruned.*

- [x] **TRK-2 — Driver location pipeline** *(deps: TRK-1, DSP-1)*
  Driver sends position every ~5s over WS → Redis geo-set + live channel of the active job; REST fallback `PUT /v1/drivers/me/location`. Snapshot to Postgres on every job transition.
  *AC: customer channel receives positions ≤5s stale; snapshots present per transition.*

- [x] **TRK-3 — Job event broadcasting** *(deps: TRK-1, JOB-3)*
  Every state transition publishes to the job channel and triggers FCM (customer: status changes; driver: offers/cancellations). FCM payloads are data messages with job id for rehydration.
  *AC: app killed → FCM arrives; app open → WS event arrives; no double-handling.*
  Correction: this was checked off when only the WS half existed --
  `app/services/realtime.py` had a `# TODO(FCM)` comment and no
  `firebase_admin.messaging` call anywhere in the backend, so the FCM half of
  the AC was never actually true. Fixed: `app/services/push.py` (`send_push`)
  wraps `firebase_admin.messaging.send` with a data-only `Message` (no
  `notification` block), reusing the same lazily-initialized Firebase Admin app
  `app/core/security.py` sets up for auth-token verification -- no-op (never
  raises) if Firebase isn't configured or the target user has no `fcm_token`.
  Wired into `broadcast_job_event` (pushes to the job's customer, and its
  assigned driver too if one is set -- covers a driver learning their assigned
  job was cancelled while backgrounded) and `notify_driver_offer` (pushes to
  the offered driver). Payload data mirrors the WS wire vocabulary
  (`lib/core/ws/server_message.dart`'s `type`/`job_id` fields) so a future
  Flutter FCM handler dispatches the same way: `{"type": "job_event",
  "job_id": ..., "status": ...}` and `{"type": "job_offer", "job_id": ...,
  "offer_id": ...}`. Tested with `firebase_admin.messaging.send` mocked
  (`tests/test_push.py`, `tests/test_ws.py`) -- never calls the real Firebase
  API. Still genuinely open: no live device/real Firebase project has ever
  received one of these pushes, and there's no Flutter-side FCM handler yet
  (TRK-4 only covers the WS half) -- both are follow-up work, not blocking this
  entry's AC as written (which is specifically about the backend triggering
  FCM, not about a device having caught one).

  Flutter half, this pass: as of the previous pass, only a foreground
  `FirebaseMessaging.onMessage` listener existed (`lib/app/di.dart`), which
  just nudged the WS socket to reconnect — it showed no system notification
  at all, and had no killed-app/backgrounded handling whatsoever. Added:
  `flutter_local_notifications` (`lib/core/notifications
  /push_notifications.dart`), a top-level
  `firebaseMessagingBackgroundHandler` registered via
  `FirebaseMessaging.onBackgroundMessage` in `main()` before `runApp` (per
  Firebase's own requirement — it runs in its own background isolate on
  Android), which shows a local notification titled/worded per the data
  message's `type` field (`job_offer`/`job_event`/generic fallback,
  mirroring the WS wire vocabulary in `lib/core/ws/server_message.dart`;
  strings added to `lib/l10n/app_es.arb`/`app_en.arb` as
  `push*Title`/`push*Body`). Notification permission
  (`NotificationPermissionRequester`, `lib/core/notifications
  /notification_permission_requester.dart`) is requested from
  `DriverHomeCubit.toggleAvailability` the same moment location permission
  already is — "ask when it's actually needed," not at app launch. Tapping
  the notification opens/foregrounds the app; a full deep-link straight to
  the job it was about is out of scope — the router's own
  authenticated-driver redirect already lands on the driver home screen
  either way, and the existing offer/job machinery picks up from there once
  the socket reconnects.

  Genuinely NOT verified — no real device or emulator was used: whether a
  system notification actually appears, whether it survives the app being
  fully killed, and whether the tap behaves as described are all unchecked.
  On iOS specifically there's a real (not just unverified) gap: Apple does
  not wake a fully terminated app for a silent/data-only push at all — only
  a push with a visible `notification` block does that, entirely through
  the OS, with no app code involved. `UIBackgroundModes: [..., 
  remote-notification]` was added to `ios/Runner/Info.plist` so the
  background handler has a chance to run while the app is merely
  *suspended* (not terminated), which is the best this data-only payload
  shape can do on iOS.

  Update: the backend half (above) and this Flutter half were built by two
  parallel agents and landed a few minutes apart — the Flutter worktree was
  created before the backend merge, so its own note above ("backend hasn't
  landed yet") was accurate at the time it was written but is now stale.
  Both halves are merged as of this pass: `backend/app/services/push.py`
  exists and sends the exact `{"type": ..., "job_id": ...}` shape this
  Flutter handler expects. Nothing else needed to change on either side —
  the client work already matched the wire shape it was built against.
  Still genuinely unverified end-to-end: no live device has received one of
  these pushes from the real backend yet.

- [x] **TRK-4 — Flutter WS client** *(deps: FND-4)*
  `core/ws/`: connect lifecycle bound to auth state, exponential reconnect, typed event stream (freezed events), rehydrate via `GET /jobs/{id}` on reconnect.
  *AC: airplane-mode toggle recovers the stream and reconciles missed events.*

- [ ] **TRK-5 — Driver background location** *(deps: TRK-2)*
  geolocator foreground-service mode (Android) + iOS background location entitlement, active only while available/on-job. Battery-sane intervals.
  *AC: locked-screen Android device keeps streaming during an active job; iOS entitlement justification drafted for review.*
  Partial: `geolocator` wired end to end while the **app is open and a job is active** — `LocationSource` abstraction, live position replacing the pickup-point placeholder in `ActiveJobCubit`, permission requested on go-available, `ACCESS_FINE/COARSE_LOCATION` (Android) + `NSLocationWhenInUseUsageDescription` (iOS) declared. Still open: true background/locked-screen tracking (Android foreground service + `ACCESS_BACKGROUND_LOCATION`, iOS "Always" entitlement + App Store justification) — that needs a real device to verify and is a distinct, riskier pass.

  Follow-up: manifest/plist prep for the still-open half, code only — NOT
  device-verified, still not checking this off. Checked `geolocator`'s own
  setup docs directly in its pub-cache copy
  (`~/.pub-cache/hosted/pub.dev/geolocator-14.0.3/README.md`) for the exact
  keys rather than guessing.

  `android/app/src/main/AndroidManifest.xml` gains
  `ACCESS_BACKGROUND_LOCATION` (what actually lets geolocator keep
  streaming fixes once backgrounded/locked, per that README) plus
  `FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_LOCATION` (the latter required
  from Android 14/SDK 34) and `POST_NOTIFICATIONS` (the foreground
  service's required ongoing notification, Android 13+). Deliberately did
  *not* add a `<service>` element: `geolocator_android`'s own
  `AndroidManifest.xml` (checked in the same pub-cache location,
  `android/src/main/AndroidManifest.xml`) already declares
  `.GeolocatorLocationService` with `android:foregroundServiceType="location"`
  — Gradle manifest-merges that into the app automatically, so redeclaring
  it here would only risk a duplicate/mismatched entry.

  `ios/Runner/Info.plist` gains `NSLocationAlwaysAndWhenInUseUsageDescription`
  (the "Always" authorization prompt string) and `UIBackgroundModes:
  [location]` (what the same README says iOS 16+ additionally requires to
  deliver fixes in the background). Neither of these makes the app request
  "Always" at runtime by itself — `LocationSource.requestPermission`
  (`lib/core/location/location_source.dart`) still only drives the
  when-in-use flow today; wiring the "Always" runtime request (and, on
  Android, actually starting geolocator in its foreground-service mode
  from `ActiveJobCubit`) is further work this pass doesn't attempt.

  Explicitly not claimed: none of this was run on a real device (or even a
  simulator/emulator) — locked-screen streaming, the foreground-service
  notification actually appearing, and the "Always" prompt's exact wording
  on-device are all unverified. This is manifest/plist prep only.

  Follow-up: the two code gaps this note flagged are both built now.
  `LocationSource` gained `requestBackgroundPermission()` (escalates an
  already-granted "while in use" grant to "always" — a no-op, never
  throwing, if declined; same "ask when needed, don't gate on the answer"
  convention as every other permission prompt in this app), called from
  `ActiveJobCubit._syncLocationTimer` the moment a job actually goes active
  — a driver who never accepts one is still only ever asked for "while in
  use". `GeolocatorLocationSource.watchPosition()` now branches on
  `defaultTargetPlatform`: Android gets `AndroidSettings` with a
  `ForegroundNotificationConfig` (persistent, non-dismissable notification,
  wake lock held) — this is what actually keeps `Geolocator.getPositionStream`
  alive once backgrounded/locked, per the same geolocator README section
  (`### Platform specific location settings`) the manifest/plist pass
  already cited; iOS gets `AppleSettings` with
  `showBackgroundLocationIndicator: true` and
  `pauseLocationUpdatesAutomatically: false`. Both fall back to the original
  plain `LocationSettings` on any other platform (desktop/tests, which use
  fakes anyway). 5 tests unaffected (`active_job_cubit_location_test.dart`
  still passes against its `_FakeLocationSource`, updated for the new
  interface method); full suite green (391 passed, up from 385).

  Still not checking this off: everything above is still exactly what the
  device-verification note above says it is — code only. Locked-screen
  streaming, the notification actually appearing, wake-lock behavior, and
  the "Always" prompt's on-device wording/flow (especially Android 11+,
  where a first in-line denial can't be re-prompted and needs a Settings
  deep-link this pass doesn't add) all still need a real device pass before
  this AC is actually met.

- [x] **TRK-6 — Share-track token backend** *(deps: TRK-3)*
  Mint `job_token` at creation; `GET /v1/track/{token}` + public WS/poll channel exposing only position, status, ETA (no PII beyond driver first name/plate).
  *AC: token works logged-out; expires after job completion + 24h.*
  Correction: this was actually built already (`Job.share_token` minted at
  creation, `GET /v1/track/{token}` + `WS /v1/ws/track/{share_token}` both
  live, PII-limited to driver first name/plate — see the WEB-4 note in
  `10-web-client.md`, which has been using this for a while) but never got
  checked off or a progress note. Auditing it surfaced one genuine gap: the
  token never expired. Fixed — both endpoints now 404/close-4004 once
  `completed_at`/`cancelled_at` is more than 24h old, matching the AC
  exactly. Tested (`test_track_expires_24h_after_completion`,
  `test_share_track_ws_closes_4004_24h_after_completion`), full suite
  green (220 passed).
