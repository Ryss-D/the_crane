import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/auth/fake_phone_auth_gateway.dart';
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
      ),
      act: (cubit) => cubit.sendCode('+573000000000'),
      expect: () => [
        const AuthState(isSendingCode: true, phoneNumber: '+573000000000'),
        const AuthState(isSendingCode: false, sendCodeFailed: true, phoneNumber: '+573000000000'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'confirmCode with a bad code surfaces confirmCodeFailed, not a crash',
      build: () => AuthCubit(
        gateway: FakePhoneAuthGateway(sendDelay: Duration.zero),
        authRepository: FakeAuthRepository(delay: Duration.zero),
      ),
      seed: () => const AuthState(
        phase: AuthPhase.codeSent,
        verificationId: 'stale-id',
      ),
      act: (cubit) => cubit.confirmCode('123456'),
      expect: () => [
        isA<AuthState>().having((s) => s.isConfirmingCode, 'isConfirmingCode', true),
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
        authRepository: FakeAuthRepository(delay: Duration.zero, role: UserRole.driver),
      ),
      act: (cubit) async {
        await cubit.sendCode('+573000000000');
        await Future<void>.delayed(Duration.zero);
        await cubit.confirmCode('123456');
        await cubit.completeProfile('Carlos Driver');
      },
      verify: (cubit) => expect(cubit.state.user?.role, UserRole.driver),
    );

    test('bootstrap syncs immediately when the gateway is already signed in', () async {
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
        authRepository: FakeAuthRepository(delay: Duration.zero, role: UserRole.customer),
      );
      expect(cubit.state.phase, AuthPhase.unauthenticated);

      await cubit.bootstrap();

      expect(cubit.state.phase, AuthPhase.needsProfile);
      expect(cubit.state.user, isNotNull);
    });
  });
}
