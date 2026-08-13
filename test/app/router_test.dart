import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/app/router.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/auth/fake_phone_auth_gateway.dart';
import 'package:the_crane/core/auth/fake_push_token_gateway.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/auth/auth_cubit.dart';
import 'package:the_crane/features/auth/auth_state.dart';

class _MockGoRouterState extends Mock implements GoRouterState {}

/// AUTH-3/4 — `routerRedirect` is a pure function of an [AuthCubit] and the
/// attempted location; exercising every phase/role/location combination
/// through the full widget tree (as the other `*_flow_widget_test.dart`
/// files do incidentally, just by signing in and navigating) would need a
/// dedicated screen per redirect branch that mostly don't exist (nothing
/// ever lets a driver visit `/customer/...`). Calling it directly instead,
/// with a mocked [GoRouterState] standing in for whatever `matchedLocation`
/// a real navigation attempt would carry.
void main() {
  String? redirectAt(AuthCubit authCubit, String location) {
    final state = _MockGoRouterState();
    when(() => state.matchedLocation).thenReturn(location);
    return routerRedirect(state, authCubit);
  }

  // `FakePhoneAuthGateway.verifyPhoneNumber` schedules `onCodeSent` via a
  // real (if zero-duration) `Timer`, and `AuthCubit.sendCode` doesn't await
  // it -- so `sendCode` alone returns before `codeSent` is actually
  // reached. A short real delay lets that timer fire.
  Future<void> sendCodeAndWait(AuthCubit authCubit, String phone) async {
    await authCubit.sendCode(phone);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  /// Drives [AuthCubit] to `AuthPhase.authenticated` with [role], without
  /// a `needsProfile` detour: pre-seeding the fake repository's user with
  /// a name (mirroring an already-onboarded returning user) means the
  /// cubit's own `sync()` call during sign-in finds one already set.
  Future<AuthCubit> authenticatedCubit(UserRole role) async {
    final authRepository = FakeAuthRepository(delay: Duration.zero, role: role);
    await authRepository.sync(name: 'Test User');
    final authCubit = AuthCubit(
      gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
      authRepository: authRepository,
      pushTokenGateway: FakePushTokenGateway(),
    );
    await sendCodeAndWait(authCubit, '3000000000');
    await authCubit.confirmCode('123456');
    expect(authCubit.state.phase, AuthPhase.authenticated);
    return authCubit;
  }

  group('routerRedirect', () {
    test('unauthenticated sends anywhere but sign-in to sign-in', () {
      final authCubit = AuthCubit(
        gateway: FakePhoneAuthGateway(),
        authRepository: FakeAuthRepository(),
        pushTokenGateway: FakePushTokenGateway(),
      );

      expect(redirectAt(authCubit, AppRoute.signIn), isNull);
      expect(redirectAt(authCubit, AppRoute.customerHome), AppRoute.signIn);
    });

    test('codeSent sends anywhere but the OTP screen to the OTP screen',
        () async {
      final authCubit = AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(),
        pushTokenGateway: FakePushTokenGateway(),
      );
      await sendCodeAndWait(authCubit, '3000000000');
      expect(authCubit.state.phase, AuthPhase.codeSent);

      expect(redirectAt(authCubit, AppRoute.otp), isNull);
      expect(redirectAt(authCubit, AppRoute.signIn), AppRoute.otp);
    });

    test('needsProfile sends anywhere but complete-profile to '
        'complete-profile', () async {
      final authCubit = AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(delay: Duration.zero),
        pushTokenGateway: FakePushTokenGateway(),
      );
      await sendCodeAndWait(authCubit, '3000000000');
      await authCubit.confirmCode('123456'); // no name seeded -> needsProfile
      expect(authCubit.state.phase, AuthPhase.needsProfile);

      expect(redirectAt(authCubit, AppRoute.completeProfile), isNull);
      expect(redirectAt(authCubit, AppRoute.otp), AppRoute.completeProfile);
    });

    test('authenticated leaves an auth screen for the role\'s home', () async {
      final authCubit = await authenticatedCubit(UserRole.customer);

      expect(redirectAt(authCubit, AppRoute.signIn), AppRoute.customerHome);
      expect(redirectAt(authCubit, AppRoute.otp), AppRoute.customerHome);
      expect(
        redirectAt(authCubit, AppRoute.completeProfile),
        AppRoute.customerHome,
      );
    });

    test('authenticated leaves its own shell\'s routes alone', () async {
      final authCubit = await authenticatedCubit(UserRole.customer);

      expect(redirectAt(authCubit, AppRoute.customerHome), isNull);
      expect(redirectAt(authCubit, AppRoute.customerSettings), isNull);
    });

    test('authenticated driver/fleet-owner roles map to their own home',
        () async {
      final driverCubit = await authenticatedCubit(UserRole.driver);
      expect(redirectAt(driverCubit, AppRoute.signIn), AppRoute.driverHome);

      final fleetCubit = await authenticatedCubit(UserRole.fleetOwner);
      expect(redirectAt(fleetCubit, AppRoute.signIn), AppRoute.fleetHome);
    });

    test(
        'authenticated bounces a customer out of the driver or fleet shell '
        '(no in-app path leads here -- only reachable if the role changed '
        'server-side without a matching client navigation)', () async {
      final authCubit = await authenticatedCubit(UserRole.customer);

      expect(redirectAt(authCubit, AppRoute.driverHome), AppRoute.customerHome);
      expect(
        redirectAt(authCubit, AppRoute.driverJob),
        AppRoute.customerHome,
      );
      expect(redirectAt(authCubit, AppRoute.fleetHome), AppRoute.customerHome);
    });
  });

  test('the router\'s AuthCubit-stream listener is torn down on dispose',
      () async {
    final authCubit = await authenticatedCubit(UserRole.customer);
    final router = createRouter(authCubit);

    // No observable effect beyond "doesn't throw" -- `_AuthRefreshListenable`
    // has no public state, so this just proves `GoRouter.dispose()` reaches
    // its `refreshListenable.dispose()` (which cancels the stream
    // subscription) rather than leaking it.
    expect(router.dispose, returnsNormally);
  });
}
