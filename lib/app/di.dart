import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/api/api_client.dart';
import '../core/api/auth_repository.dart';
import '../core/api/drivers_repository.dart';
import '../core/api/fake_auth_repository.dart';
import '../core/api/fake_drivers_repository.dart';
import '../core/api/fake_jobs_repository.dart';
import '../core/api/jobs_repository.dart';
import '../core/auth/fake_phone_auth_gateway.dart';
import '../core/auth/fake_push_token_gateway.dart';
import '../core/auth/phone_auth_gateway.dart';
import '../core/auth/push_token_gateway.dart';
import '../core/config/env.dart';
import '../core/location/location_source.dart';
import '../core/ws/crane_socket.dart';
import '../features/auth/auth_cubit.dart';

// TODO(FND-6): construct google_maps here once Maps keys and native setup
// are in place. Driver location (TRK-5) is separate and already wired below
// via GeolocatorLocationSource.

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
    required this.authCubit,
    this.socket,
    this.locationSource,
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
  factory AppDependencies.fromEnv() {
    final dio = createDio(baseUrl: Env.apiBaseUrl);
    if (Env.useFakeBackend) {
      final jobs = FakeJobsRepository();
      // Shared with the drivers fake so AUTH-5's `registerDriver` can flip
      // this same fake user's role to driver, mirroring the real backend's
      // single-request role flip (see `FakeAuthRepository.debugPromoteToDriver`).
      final authRepository = FakeAuthRepository();
      return AppDependencies(
        dio: dio,
        jobsRepository: jobs,
        driversRepository:
            FakeDriversRepository(jobs: jobs, auth: authRepository),
        authCubit: AuthCubit(
          gateway: FakePhoneAuthGateway(),
          authRepository: authRepository,
          pushTokenGateway: FakePushTokenGateway(),
        ),
      );
    }
    final socket = CraneSocket(tokenProvider: _firebaseIdToken)..connect();
    return AppDependencies(
      dio: dio,
      jobsRepository: ApiJobsRepository(dio, socket),
      driversRepository: ApiDriversRepository(dio, socket),
      socket: socket,
      locationSource: GeolocatorLocationSource(),
      authCubit: AuthCubit(
        gateway: FirebasePhoneAuthGateway(),
        authRepository: ApiAuthRepository(dio),
        pushTokenGateway: FirebasePushTokenGateway(),
      ),
    );
  }

  final Dio dio;
  final JobsRepository jobsRepository;
  final DriversRepository driversRepository;
  final AuthCubit authCubit;

  /// Null when [Env.useFakeBackend] is true — the fakes don't use a socket.
  final CraneSocket? socket;

  /// Null when [Env.useFakeBackend] is true — nothing needs real GPS.
  final LocationSource? locationSource;
}
