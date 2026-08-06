import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/auth_repository.dart';
import '../../core/auth/phone_auth_gateway.dart';
import '../../core/auth/push_token_gateway.dart';
import 'auth_state.dart';

/// Drives phone-OTP sign-in end to end: send code, confirm code, sync the
/// backend profile, (once) collect a name if the profile has none yet, and
/// register/refresh/clear the device's FCM token (AUTH-6). The single
/// source of truth for `routerRedirect` (`lib/app/router.dart`).
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required PhoneAuthGateway gateway,
    required AuthRepository authRepository,
    required PushTokenGateway pushTokenGateway,
  })  : _gateway = gateway,
        _authRepository = authRepository,
        _pushTokenGateway = pushTokenGateway,
        super(const AuthState()) {
    _refreshSub = _pushTokenGateway.onTokenRefresh.listen((token) {
      if (state.isAuthenticated) {
        unawaited(_authRepository.updateFcmToken(token));
      }
    });
  }

  final PhoneAuthGateway _gateway;
  final AuthRepository _authRepository;
  final PushTokenGateway _pushTokenGateway;
  late final StreamSubscription<String> _refreshSub;

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
    final authenticated = user.name != null;
    emit(state.copyWith(
      phase: authenticated ? AuthPhase.authenticated : AuthPhase.needsProfile,
      user: user,
    ));
    if (authenticated) unawaited(_registerPushToken());
  }

  Future<void> completeProfile(String name) async {
    final user = await _authRepository.updateProfile(name: name);
    emit(state.copyWith(phase: AuthPhase.authenticated, user: user));
    unawaited(_registerPushToken());
  }

  Future<void> _registerPushToken() async {
    final token = await _pushTokenGateway.getToken();
    if (token != null) {
      await _authRepository.updateFcmToken(token);
    }
  }

  Future<void> signOut() async {
    // Clear the token while the (still-valid) Firebase session can
    // authenticate the request — signing out of Firebase first would make
    // this PATCH 401.
    if (state.isAuthenticated) {
      await _authRepository.updateFcmToken(null);
    }
    await _gateway.signOut();
    emit(const AuthState());
  }

  @override
  Future<void> close() {
    unawaited(_refreshSub.cancel());
    return super.close();
  }
}
