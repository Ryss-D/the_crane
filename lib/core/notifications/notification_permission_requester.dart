/// TRK-3: requests whatever platform permission a killed-app/backgrounded
/// FCM push needs to actually surface a system notification (iOS's
/// alert/sound/badge prompt, Android 13+'s runtime notifications
/// permission) — abstracted so `DriverHomeCubit` doesn't depend on
/// `firebase_messaging`/`flutter_local_notifications` directly, same
/// injectable-seam pattern as [LocationSource]/[PushTokenGateway].
///
/// Asked "when it's actually needed" rather than at app launch: the driver
/// going available for the first time (see `DriverHomeCubit
/// .toggleAvailability`), mirroring exactly how [LocationSource
/// .requestPermission] is already asked at that same moment. Every call
/// after the first is a no-op from the OS's perspective once permission has
/// already been decided, so there's no need to track "first time" here —
/// same reasoning [LocationSource] already relies on.
abstract interface class NotificationPermissionRequester {
  Future<void> requestPermission();
}
