import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/models/app_user.dart';

part 'auth_state.freezed.dart';

/// Where the phone-OTP + profile-sync flow currently stands.
enum AuthPhase {
  /// No Firebase session — show the phone entry screen.
  unauthenticated,

  /// Code sent, waiting for the user to enter it.
  codeSent,

  /// Firebase sign-in done; fetching/creating the backend profile.
  syncing,

  /// Signed in, but the backend has no name yet — ask for it once.
  needsProfile,

  /// Fully signed in with a synced profile — router sends the user home.
  authenticated,
}

@freezed
abstract class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState({
    @Default(AuthPhase.unauthenticated) AuthPhase phase,
    @Default(false) bool isSendingCode,
    @Default(false) bool sendCodeFailed,
    @Default(false) bool isConfirmingCode,
    @Default(false) bool confirmCodeFailed,
    String? verificationId,
    String? phoneNumber,
    AppUser? user,
  }) = _AuthState;

  bool get isAuthenticated => phase == AuthPhase.authenticated;
}
