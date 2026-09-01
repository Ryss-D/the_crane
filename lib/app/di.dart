import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/api/api_client.dart';
import '../core/api/auth_repository.dart';
import '../core/api/directions_repository.dart';
import '../core/api/drivers_repository.dart';
import '../core/api/fake_auth_repository.dart';
import '../core/api/fake_directions_repository.dart';
import '../core/api/fake_drivers_repository.dart';
import '../core/api/fake_fleet_repository.dart';
import '../core/api/fake_jobs_repository.dart';
import '../core/api/fake_places_repository.dart';
import '../core/api/fake_vehicles_repository.dart';
import '../core/api/fleet_repository.dart';
import '../core/api/jobs_repository.dart';
import '../core/api/places_repository.dart';
import '../core/api/vehicles_repository.dart';
import '../core/auth/fake_phone_auth_gateway.dart';
import '../core/auth/fake_push_token_gateway.dart';
import '../core/auth/phone_auth_gateway.dart';
import '../core/auth/push_token_gateway.dart';
import '../core/config/env.dart';
import '../core/location/location_source.dart';
import '../core/notifications/notification_permission_requester.dart';
import '../core/notifications/push_notifications.dart';
import '../core/storage/active_job_store.dart';
import '../core/storage/document_image_picker.dart';
import '../core/storage/document_upload_repository.dart';
import '../core/storage/fake_document_image_picker.dart';
import '../core/storage/fake_document_upload_repository.dart';
import '../core/ws/crane_socket.dart';
import '../features/auth/auth_cubit.dart';

Future<String?> _firebaseIdToken() =>
    FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

/// Composition root: builds the HTTP client and repositories once at app
/// start. The instances are exposed to the widget tree through
/// `MultiRepositoryProvider` in `main.dart`.
class AppDependencies {
  AppDependencies({
    required this.dio,
    required this.jobsRepository,
    required this.driversRepository,
    required this.vehiclesRepository,
    required this.fleetRepository,
    required this.placesRepository,
    required this.directionsRepository,
    required this.documentUploadRepository,
    required this.documentImagePicker,
    required this.authCubit,
    required this.activeJobStore,
    this.socket,
    this.locationSource,
    this.notificationPermissionRequester,
  });

  /// Production wiring for the active flavor.
  ///
  /// [Env.useFakeBackend] (default true) selects seeded in-memory fakes;
  /// once the FastAPI backend is reachable, set `USE_FAKE_BACKEND=false` in
  /// the flavor env file and the dio implementations take over — no code
  /// changes. The fake drivers repo shares the fake jobs repo so a
  /// dev-triggered offer can be accepted end to end.
  ///
  /// The api-backed branch also opens one shared [CraneSocket] (TRK-4):
  /// both repositories push/pull through it, and it's exposed on
  /// [AppDependencies.socket] so `ActiveJobCubit` can send driver location
  /// fixes over the same connection. [locationSource] (TRK-5) is the real
  /// GPS feed for those fixes — null under fakes, where nothing needs one.
  ///
  /// [authCubit] (AUTH-3/4) picks [FakePhoneAuthGateway]/[FakeAuthRepository]
  /// under fakes (any phone + any code, always a fresh customer) or the real
  /// Firebase phone-auth gateway + `/auth/sync` otherwise — same flag as
  /// everything else, so dev iteration never needs real SMS.
  /// [activeJobStore] (CUS-4) is obtained by the caller (`main()`, which can
  /// `await SharedPreferences.getInstance()` before this synchronous
  /// factory runs) rather than by this factory itself — same reasoning as
  /// `authCubit.bootstrap()` being a separate awaited step after
  /// construction.
  factory AppDependencies.fromEnv({required ActiveJobStore activeJobStore}) {
    final dio = createDio(baseUrl: Env.apiBaseUrl);
    if (Env.useFakeBackend) {
      final jobs = FakeJobsRepository();
      // Shared with the drivers fake so AUTH-5's `registerDriver` can flip
      // this same fake user's role to driver, mirroring the real backend's
      // single-request role flip (see `FakeAuthRepository.debugPromoteToDriver`).
      final authRepository = FakeAuthRepository();
      // FLT-4: shared with the drivers fake too, so redeeming an invite
      // token in `registerDriver` links onto the exact truck this fake
      // fleet repo pre-provisioned in `createInvite`.
      final fleetRepository = FakeFleetRepository(auth: authRepository);
      return AppDependencies(
        dio: dio,
        jobsRepository: jobs,
        driversRepository: FakeDriversRepository(
          jobs: jobs,
          auth: authRepository,
          fleet: fleetRepository,
        ),
        vehiclesRepository: FakeVehiclesRepository(),
        fleetRepository: fleetRepository,
        placesRepository: FakePlacesRepository(),
        directionsRepository: FakeDirectionsRepository(),
        documentUploadRepository: FakeDocumentUploadRepository(),
        documentImagePicker: FakeDocumentImagePicker(),
        authCubit: AuthCubit(
          gateway: FakePhoneAuthGateway(),
          authRepository: authRepository,
          pushTokenGateway: FakePushTokenGateway(),
          activeJobStore: activeJobStore,
        ),
        activeJobStore: activeJobStore,
      );
    }
    final socket = CraneSocket(tokenProvider: _firebaseIdToken)..connect();
    // DRV-2: nudge the socket to reconnect right now (skipping whatever
    // backoff delay it's mid-wait on) whenever a data message arrives while
    // the app is foregrounded, rather than waiting out the backoff to
    // notice a stale connection. Deliberately payload-agnostic: this just
    // nudges the socket on *any* incoming data push, no matter its `type` —
    // the backend does send real FCM pushes now (`realtime.py`'s
    // `_push_to_user`/`send_push`), but there's no reason to special-case
    // which ones trigger a reconnect check.
    // Deliberately scoped to foreground/resumed only — the killed-app/
    // backgrounded case is handled separately, by
    // `core/notifications/push_notifications.dart`'s
    // `firebaseMessagingBackgroundHandler` (registered in `main()`), which
    // shows a real system notification via `flutter_local_notifications`
    // instead of just nudging the socket (there's no socket to nudge if the
    // app isn't running at all).
    FirebaseMessaging.onMessage.listen((_) => socket.reconnectNow());
    return AppDependencies(
      dio: dio,
      jobsRepository: ApiJobsRepository(dio, socket),
      driversRepository: ApiDriversRepository(dio, socket),
      vehiclesRepository: ApiVehiclesRepository(dio),
      fleetRepository: ApiFleetRepository(dio),
      placesRepository: ApiPlacesRepository(dio),
      directionsRepository: ApiDirectionsRepository(dio),
      // AUTH-5 follow-up: same Firebase project (FND-1) already wired for
      // Auth/Messaging, just a new SDK (Storage) -- see
      // `lib/core/storage/document_upload_repository.dart`.
      documentUploadRepository: FirebaseDocumentUploadRepository(),
      documentImagePicker: ImagePickerDocumentPicker(),
      socket: socket,
      locationSource: GeolocatorLocationSource(),
      // TRK-3: the same singleton `main()` already called `init()` on
      // before `runApp` — `DriverHomeCubit.toggleAvailability` is the
      // on-demand caller of `requestPermission()` (see that class).
      notificationPermissionRequester: PushNotifications.instance,
      authCubit: AuthCubit(
        gateway: FirebasePhoneAuthGateway(),
        authRepository: ApiAuthRepository(dio),
        pushTokenGateway: FirebasePushTokenGateway(),
        activeJobStore: activeJobStore,
      ),
      activeJobStore: activeJobStore,
    );
  }

  final Dio dio;
  final JobsRepository jobsRepository;
  final DriversRepository driversRepository;
  final VehiclesRepository vehiclesRepository;
  final FleetRepository fleetRepository;
  final PlacesRepository placesRepository;
  final DirectionsRepository directionsRepository;

  /// AUTH-5 follow-up (2026-08-31): real Firebase Storage uploads /
  /// `image_picker` gallery chooser for `BecomeDriverScreen`'s document
  /// fields, real or fake per [Env.useFakeBackend] same as everything else.
  final DocumentUploadRepository documentUploadRepository;
  final DocumentImagePicker documentImagePicker;
  final AuthCubit authCubit;

  /// CUS-4: which job (if any) to resume on next launch — real in both fake-
  /// and real-backend dev modes (rehydration is orthogonal to which backend
  /// answers `getJob`), unlike [socket]/[locationSource]/
  /// [notificationPermissionRequester] below, which only exist for real.
  final ActiveJobStore activeJobStore;

  /// Null when [Env.useFakeBackend] is true — the fakes don't use a socket.
  final CraneSocket? socket;

  /// Null when [Env.useFakeBackend] is true — nothing needs real GPS.
  final LocationSource? locationSource;

  /// Null when [Env.useFakeBackend] is true — nothing there needs a real
  /// device permission prompt (TRK-3).
  final NotificationPermissionRequester? notificationPermissionRequester;
}
