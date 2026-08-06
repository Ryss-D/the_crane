import 'package:firebase_auth/firebase_auth.dart';

/// Wraps the exact Firebase phone-auth calls `AuthCubit` needs — the same
/// seam pattern as `LocationSource` for geolocator: tests inject
/// [FakePhoneAuthGateway] instead of touching real Firebase.
abstract interface class PhoneAuthGateway {
  /// Starts phone verification; calls back with the verification id once
  /// Firebase (or the SMS carrier) has sent the code, with an error message
  /// if sending failed (bad number, quota, etc.), or with [onAutoVerified]
  /// if the platform completed sign-in itself without a code (Android
  /// instant validation) — the caller should treat that exactly like a
  /// successful [confirmCode].
  void verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  });

  /// Confirms the code, completing Firebase sign-in. Throws on a bad code.
  Future<void> confirmCode(String verificationId, String smsCode);

  Future<void> signOut();

  /// True if a Firebase user is already signed in (e.g. a resumed session).
  bool get isSignedIn;
}

class FirebasePhoneAuthGateway implements PhoneAuthGateway {
  @override
  void verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android auto-retrieval/instant validation — sign in directly.
        await FirebaseAuth.instance.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (e) => onError(e.message ?? e.code),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) => onCodeSent(verificationId),
    );
  }

  @override
  Future<void> confirmCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;
}
