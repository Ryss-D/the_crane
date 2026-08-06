import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/auth_repository.dart';
import '../../core/auth/phone_auth_gateway.dart';
import 'auth_state.dart';

/// Drives phone-OTP sign-in end to end: send code, confirm code, sync the
/// backend profile, and (once) collect a name if the profile has none yet.
/// The single source of truth for `routerRedirect` (`lib/app/router.dart`).
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required PhoneAuthGateway gateway,
    required AuthRepository authRepository,
  })  : _gateway = gateway,
        _authRepository = authRepository,
        super(const AuthState());

  final PhoneAuthGateway _gateway;
  final AuthRepository _authRepository;

  /// Call once at startup (before the first frame) — if a Firebase session
  /// already exists, skip straight to syncing instead of the phone screen.
  Future<void> bootstrap() async {
    if (_gateway.isSignedIn) {
      await _afterSignIn();
    }
  }

  Future<void> sendCode(String phoneNumber) async {
    emit(state.copyWith(
      isSendingCode: true,
      sendCodeFailed: false,
      phoneNumber: phoneNumber,
    ));
    _gateway.verifyPhoneNumber(
      phoneNumber,
      onCodeSent: (verificationId) {
        emit(state.copyWith(
          phase: AuthPhase.codeSent,
          isSendingCode: false,
          verificationId: verificationId,
        ));
      },
      onError: (_) {
        emit(state.copyWith(isSendingCode: false, sendCodeFailed: true));
      },
      onAutoVerified: () {
        unawaited(_afterSignIn());
      },
    );
  }

  Future<void> confirmCode(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return;
    emit(state.copyWith(isConfirmingCode: true, confirmCodeFailed: false));
    try {
      await _gateway.confirmCode(verificationId, smsCode);
      await _afterSignIn();
    } catch (_) {
      emit(state.copyWith(isConfirmingCode: false, confirmCodeFailed: true));
    }
  }

  Future<void> _afterSignIn() async {
    emit(state.copyWith(phase: AuthPhase.syncing, isConfirmingCode: false));
    final user = await _authRepository.sync();
    emit(state.copyWith(
      phase: user.name == null ? AuthPhase.needsProfile : AuthPhase.authenticated,
      user: user,
    ));
  }

  Future<void> completeProfile(String name) async {
    final user = await _authRepository.updateProfile(name: name);
    emit(state.copyWith(phase: AuthPhase.authenticated, user: user));
  }

  Future<void> signOut() async {
    await _gateway.signOut();
    emit(const AuthState());
  }
}
