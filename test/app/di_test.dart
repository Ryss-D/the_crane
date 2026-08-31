import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/app/di.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/fake_vehicles_repository.dart';

import '../support/in_memory_active_job_store.dart';

/// `Env.useFakeBackend` is a compile-time constant (`bool.fromEnvironment`)
/// that defaults to `true`; a plain `flutter test` run (no
/// `--dart-define=USE_FAKE_BACKEND=false`) always takes that branch. The
/// real-backend branch constructs a live `Dio`/`CraneSocket` and touches
/// `FirebaseAuth`/`FirebaseMessaging` statics with no injectable seam (see
/// `AuthInterceptor`/`FirebasePhoneAuthGateway`/`FirebasePushTokenGateway`),
/// so it isn't exercised here — same "thin platform passthrough" call as
/// those gateways' real implementations.
void main() {
  group('AppDependencies.fromEnv (Env.useFakeBackend == true, the default)', () {
    test('wires every repository to its in-memory fake', () {
      final deps = AppDependencies.fromEnv(
        activeJobStore: InMemoryActiveJobStore(),
      );

      expect(deps.jobsRepository, isA<FakeJobsRepository>());
      expect(deps.driversRepository, isA<FakeDriversRepository>());
      expect(deps.vehiclesRepository, isA<FakeVehiclesRepository>());
      expect(deps.fleetRepository, isA<FakeFleetRepository>());
    });

    test('leaves the real-backend-only seams null', () {
      final deps = AppDependencies.fromEnv(
        activeJobStore: InMemoryActiveJobStore(),
      );

      // Nothing under fakes needs a socket, real GPS, or a device
      // notification-permission prompt.
      expect(deps.socket, isNull);
      expect(deps.locationSource, isNull);
      expect(deps.notificationPermissionRequester, isNull);
    });

    test('drivers and fleet repositories are both the Fake* implementations '
        '(the constructor-level sharing of one FakeAuthRepository between '
        'them, per fromEnv\'s own comments, has no public seam to assert on '
        'directly)', () {
      final deps = AppDependencies.fromEnv(
        activeJobStore: InMemoryActiveJobStore(),
      );

      expect(deps.driversRepository, isA<FakeDriversRepository>());
      expect(deps.fleetRepository, isA<FakeFleetRepository>());
    });

    test('authCubit starts unauthenticated (fresh customer) without '
        'touching real Firebase', () async {
      final deps = AppDependencies.fromEnv(
        activeJobStore: InMemoryActiveJobStore(),
      );

      // FakePhoneAuthGateway.isSignedIn is always false, so bootstrap()
      // completes without emitting a signed-in state — proves the fake
      // gateway, not FirebasePhoneAuthGateway, was wired in.
      await deps.authCubit.bootstrap();

      expect(deps.authCubit.state.isAuthenticated, isFalse);
    });
  });
}
