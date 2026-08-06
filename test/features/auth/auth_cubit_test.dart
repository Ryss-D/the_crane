import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/auth/fake_phone_auth_gateway.dart';
import 'package:the_crane/core/auth/fake_push_token_gateway.dart';
import 'package:the_crane/core/auth/phone_auth_gateway.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/auth/auth_cubit.dart';
import 'package:the_crane/features/auth/auth_state.dart';

/// Always fails to send — exercises the error path
/// [FakePhoneAuthGateway] can't (it never fails on its own).
class _FailingSendGateway implements PhoneAuthGateway {
  @override
  bool get isSignedIn => false;

  @override
  void verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) {
    onError('quota-exceeded');
  }

  @override
  Future<void> confirmCode(String verificationId, String smsCode) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'sendCode success moves to codeSent with the verification id',
      build: () => AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(delay: Duration.zero),
        pushTokenGateway: FakePushTokenGateway(),
      ),
      act: (cubit) => cubit.sendCode('+573000000000'),
      expect: () => [
        const AuthState(isSendingCode: true, phoneNumber: '+573000000000'),
        isA<AuthState>()
            .having((s) => s.phase, 'phase', AuthPhase.codeSent)
            .having((s) => s.isSendingCode, 'isSendingCode', false)
            .having((s) => s.verificationId, 'verificationId', isNotNull),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'sendCode failure surfaces sendCodeFailed',
      build: () => AuthCubit(
        gateway: _FailingSendGateway(),
        authRepository: FakeAuthRepository(delay: Duration.zero),
        pushTokenGateway: FakePushTokenGateway(),
      ),
      act: (cubit) => cubit.sendCode('+573000000000'),
      expect: () => [
        const AuthState(isSendingCode: true, phoneNumber: '+573000000000'),
        const AuthState(
          isSendingCode: false,
          sendCodeFailed: true,
          phoneNumber: '+573000000000',
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'confirmCode with a bad code surfaces confirmCodeFailed, not a crash',
      build: () => AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(delay: Duration.zero),
        pushTokenGateway: FakePushTokenGateway(),
      ),
      seed: () => const AuthState(
        phase: AuthPhase.codeSent,
        verificationId: 'stale-id',
      ),
      act: (cubit) => cubit.confirmCode('123456'),
      expect: () => [
        isA<AuthState>().having(
          (s) => s.isConfirmingCode,
          'isConfirmingCode',
          true,
        ),
        isA<AuthState>()
            .having((s) => s.isConfirmingCode, 'isConfirmingCode', false)
            .having((s) => s.confirmCodeFailed, 'confirmCodeFailed', true),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'full happy path: send -> confirm -> needsProfile -> completeProfile -> authenticated',
      build: () => AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(delay: Duration.zero),
        pushTokenGateway: FakePushTokenGateway(),
      ),
      act: (cubit) async {
        await cubit.sendCode('+573000000000');
        // FakePhoneAuthGateway's onCodeSent fires via Future.delayed, even
        // with sendDelay: Duration.zero — give it a turn of the event loop.
        await Future<void>.delayed(Duration.zero);
        await cubit.confirmCode('123456');
        await cubit.completeProfile('Sofía Test');
      },
      verify: (cubit) {
        expect(cubit.state.phase, AuthPhase.authenticated);
        expect(cubit.state.user?.name, 'Sofía Test');
        expect(cubit.state.user?.role, UserRole.customer);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'a driver-role fake repository lands on authenticated with role driver',
      build: () => AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(
          delay: Duration.zero,
          role: UserRole.driver,
        ),
        pushTokenGateway: FakePushTokenGateway(),
      ),
      act: (cubit) async {
        await cubit.sendCode('+573000000000');
        await Future<void>.delayed(Duration.zero);
        await cubit.confirmCode('123456');
        await cubit.completeProfile('Carlos Driver');
      },
      verify: (cubit) => expect(cubit.state.user?.role, UserRole.driver),
    );

    test(
      'bootstrap syncs immediately when the gateway is already signed in',
      () async {
        // Drive the gateway directly (not through a cubit) to simulate a
        // resumed session — a real app would have signed in during a
        // previous launch.
        final gateway = FakePhoneAuthGateway(sendDelay: Duration.zero);
        String? verificationId;
        gateway.verifyPhoneNumber(
          '+573000000000',
          onCodeSent: (id) => verificationId = id,
          onError: (_) {},
          onAutoVerified: () {},
        );
        await Future<void>.delayed(Duration.zero);
        await gateway.confirmCode(verificationId!, '123456');
        expect(gateway.isSignedIn, isTrue);

        final cubit = AuthCubit(
          gateway: gateway,
          authRepository: FakeAuthRepository(
            delay: Duration.zero,
            role: UserRole.customer,
          ),
          pushTokenGateway: FakePushTokenGateway(),
        );
        expect(cubit.state.phase, AuthPhase.unauthenticated);

        await cubit.bootstrap();

        expect(cubit.state.phase, AuthPhase.needsProfile);
        expect(cubit.state.user, isNotNull);
      },
    );

    test('AUTH-6: registers the FCM token on sign-in and clears it on sign-out', () async {
      final authRepository = FakeAuthRepository(delay: Duration.zero);
      final cubit = AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: authRepository,
        pushTokenGateway: FakePushTokenGateway(token: 'device-token-1'),
      );

      await cubit.sendCode('+573000000000');
      await Future<void>.delayed(Duration.zero);
      await cubit.confirmCode('123456');
      await cubit.completeProfile('Sofía Test');
      // _registerPushToken runs unawaited off completeProfile's emit, and
      // itself awaits two more zero-duration timers (getToken, then
      // updateFcmToken) — a plain Duration.zero delay here can still race
      // ahead of them, so give it real (if tiny) headroom.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(authRepository.lastFcmToken, 'device-token-1');

      await cubit.signOut();
      expect(authRepository.lastFcmToken, isNull);
    });

    test('AUTH-6: a refreshed token re-registers only while authenticated', () async {
      final authRepository = FakeAuthRepository(delay: Duration.zero);
      final pushGateway = FakePushTokenGateway(token: 'device-token-1');
      final cubit = AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: authRepository,
        pushTokenGateway: pushGateway,
      );

      // Not authenticated yet — a refresh event must be ignored.
      pushGateway.emitRefresh('too-early');
      await Future<void>.delayed(Duration.zero);
      expect(authRepository.lastFcmToken, isNull);

      await cubit.sendCode('+573000000000');
      await Future<void>.delayed(Duration.zero);
      await cubit.confirmCode('123456');
      await cubit.completeProfile('Sofía Test');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      pushGateway.emitRefresh('rotated-token');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(authRepository.lastFcmToken, 'rotated-token');
    });

    test(
      'AUTH-5: refreshUser re-syncs the profile so a role flip is picked up',
      () async {
        final authRepository = FakeAuthRepository(delay: Duration.zero);
        final cubit = AuthCubit(
          gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
          authRepository: authRepository,
          pushTokenGateway: FakePushTokenGateway(),
        );

        await cubit.sendCode('+573000000000');
        await Future<void>.delayed(Duration.zero);
        await cubit.confirmCode('123456');
        await cubit.completeProfile('Sofía Test');
        expect(cubit.state.user?.role, UserRole.customer);

        // Simulates DriversRepository.registerDriver's role flip, which
        // happens out of band from AuthCubit (see
        // FakeDriversRepository.registerDriver /
        // FakeAuthRepository.debugPromoteToDriver).
        authRepository.debugPromoteToDriver();
        await cubit.refreshUser();

        expect(cubit.state.phase, AuthPhase.authenticated);
        expect(cubit.state.user?.role, UserRole.driver);
      },
    );

    test('refreshUser is a no-op when not authenticated', () async {
      final authRepository = FakeAuthRepository(delay: Duration.zero);
      final cubit = AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: authRepository,
        pushTokenGateway: FakePushTokenGateway(),
      );

      await cubit.refreshUser();
      expect(cubit.state, const AuthState());
    });
  });
}
