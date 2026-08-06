import 'dart:async';

import 'phone_auth_gateway.dart';

/// Dev/test double: `verifyPhoneNumber` "sends" a code immediately (no real
/// SMS), and [confirmCode] accepts any non-empty code.
class FakePhoneAuthGateway implements PhoneAuthGateway {
  FakePhoneAuthGateway({this.sendDelay = const Duration(milliseconds: 200)});

  final Duration sendDelay;
  bool _signedIn = false;
  String? _pendingVerificationId;
  int _seq = 0;

  @override
  bool get isSignedIn => _signedIn;

  @override
  void verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) {
    _pendingVerificationId = 'fake-verification-${++_seq}';
    Future<void>.delayed(sendDelay, () => onCodeSent(_pendingVerificationId!));
  }

  @override
  Future<void> confirmCode(String verificationId, String smsCode) async {
    if (verificationId != _pendingVerificationId) {
      throw Exception('Unknown or expired verification id');
    }
    if (smsCode.trim().isEmpty) {
      throw Exception('Code is required');
    }
    _signedIn = true;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _pendingVerificationId = null;
  }
}
