import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/app/di.dart';
import 'package:the_crane/core/api/api_client.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/fake_vehicles_repository.dart';
import 'package:the_crane/core/auth/fake_phone_auth_gateway.dart';
import 'package:the_crane/core/auth/fake_push_token_gateway.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/auth/auth_cubit.dart';

/// Fast fake jobs repo for tests (delays measured in a few ms so widget
/// tests can pump them deterministically).
FakeJobsRepository fastFakeJobs({
  Duration matchingDelay = const Duration(milliseconds: 300),
  FakeMatchingOutcome matchingOutcome = FakeMatchingOutcome.assigned,
}) {
  return FakeJobsRepository(
    quoteDelay: const Duration(milliseconds: 20),
    createDelay: const Duration(milliseconds: 20),
    actionDelay: const Duration(milliseconds: 10),
    matchingDelay: matchingDelay,
    matchingOutcome: matchingOutcome,
  );
}

/// Composition root for tests: fake repositories with short delays.
///
/// [authRole] picks which shell a completed sign-in lands on — pass
/// [UserRole.driver] for driver-flow tests that need to reach the driver
/// shell. Tests still drive the real phone+OTP screens (any number, any
/// code — see [FakePhoneAuthGateway]/[FakeAuthRepository]); nothing bypasses
/// the router's real redirect logic.
AppDependencies testDependencies({
  FakeJobsRepository? jobs,
  FakeDriversRepository? drivers,
  FakeVehiclesRepository? vehicles,
  UserRole authRole = UserRole.customer,
}) {
  final jobsRepository = jobs ?? fastFakeJobs();
  final authRepository = FakeAuthRepository(
    delay: const Duration(milliseconds: 10),
    role: authRole,
  );
  return AppDependencies(
    dio: createDio(baseUrl: 'http://localhost:8000'),
    jobsRepository: jobsRepository,
    driversRepository:
        drivers ??
        FakeDriversRepository(
          jobs: jobsRepository,
          auth: authRepository,
          actionDelay: const Duration(milliseconds: 20),
        ),
    vehiclesRepository:
        vehicles ?? FakeVehiclesRepository(delay: const Duration(milliseconds: 10)),
    authCubit: AuthCubit(
      gateway: FakePhoneAuthGateway(
        sendDelay: const Duration(milliseconds: 10),
      ),
      authRepository: authRepository,
      pushTokenGateway: FakePushTokenGateway(),
    ),
  );
}

/// Drives the real phone → OTP → profile-completion flow (any number, any
/// code, per [FakePhoneAuthGateway]/[FakeAuthRepository]) so widget tests
/// reach their target shell through the router's actual redirect logic
/// rather than a debug-only bypass. Assumes `TheCraneApp` is already pumped
/// and sitting on the sign-in screen.
Future<void> signIn(WidgetTester tester, {String name = 'Sofía Test'}) async {
  await tester.enterText(
    find.byKey(const Key('signInPhoneField')),
    '3000000000',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('sendCodeButton')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('otpCodeField')), '123456');
  await tester.pump();
  await tester.tap(find.byKey(const Key('confirmCodeButton')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('completeProfileNameField')),
    name,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('completeProfileSaveButton')));
  await tester.pumpAndSettle();
}
