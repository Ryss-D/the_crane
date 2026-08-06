import 'package:firebase_messaging/firebase_messaging.dart';

/// Wraps the exact `firebase_messaging` calls `AuthCubit` needs — same
/// injectable-seam pattern as [PhoneAuthGateway]/[LocationSource].
abstract interface class PushTokenGateway {
  /// The device's current FCM token, or null if unavailable (permission
  /// denied, simulator without push capability, etc.).
  Future<String?> getToken();

  /// Fires whenever the OS rotates the token — the caller re-registers it.
  Stream<String> get onTokenRefresh;
}

class FirebasePushTokenGateway implements PushTokenGateway {
  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}
