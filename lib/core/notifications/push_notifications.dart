import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/app_localizations.dart';
import 'notification_permission_requester.dart';

/// TRK-3: turns a killed-app/backgrounded FCM push into a real system
/// notification.
///
/// The backend (`backend/app/services/realtime.py`'s `notify_driver_offer`,
/// plus `broadcast_job_event` once its own FCM leg lands) sends *data-only*
/// messages — no `notification` block — with a `type` field mirroring the
/// WS wire vocabulary (`job_offer`/`job_event`/…, see
/// `lib/core/ws/server_message.dart`) plus `job_id`. A data-only message is
/// delivered silently with no UI unless the app builds one itself: that's
/// this file's job, via `flutter_local_notifications`.
///
/// [firebaseMessagingBackgroundHandler] is what actually catches the
/// killed-app/backgrounded case. Per Firebase's own requirement it MUST be a
/// top-level (or static) function — on Android it runs in its own
/// background isolate with none of `main()`'s state (a fresh, minimal
/// engine spun up just for this callback), so it re-initializes Firebase
/// and builds its own local-notifications plugin instance from scratch
/// rather than reusing [PushNotifications.instance]'s.
///
/// NOT verified on a real device: whether this actually shows a system
/// notification, survives the app being killed, or (on iOS specifically)
/// is delivered at all in that state — see the TRK-3 doc note in
/// `docs/tasks/05-realtime-tracking.md` for why that's a real, not merely
/// theoretical, gap on iOS.
const _androidChannelId = 'job_updates';
const _androidChannelName = 'Actualizaciones de servicio';
const _androidChannelDescription =
    'Notificaciones de nuevas ofertas y cambios de estado de tus servicios.';

const _androidChannel = AndroidNotificationChannel(
  _androidChannelId,
  _androidChannelName,
  description: _androidChannelDescription,
  importance: Importance.high,
);

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _androidChannelId,
    _androidChannelName,
    channelDescription: _androidChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
  await _showForMessage(plugin, message);
}

/// Maps an FCM data message's `type` field to a localized (title, body)
/// pair — a generic fallback pair for a type this client doesn't recognize,
/// same forward-compatible stance `ServerMessage.fromWire` takes for the WS
/// side. Pulled out of [_showForMessage] as a pure function (no plugin, no
/// platform channel) specifically so this mapping is unit-testable without
/// dragging in Firebase or `flutter_local_notifications`.
@visibleForTesting
(String, String) notificationTextFor(String? type, AppLocalizations l10n) {
  return switch (type) {
    'job_offer' => (l10n.pushJobOfferTitle, l10n.pushJobOfferBody),
    'job_event' => (l10n.pushJobEventTitle, l10n.pushJobEventBody),
    _ => (l10n.pushGenericTitle, l10n.pushGenericBody),
  };
}

/// Builds the title/body from [message.data]'s `type` (see
/// [notificationTextFor]) and shows it via [plugin].
///
/// The app's locale is hardcoded to `es` (see `main.dart`'s
/// `MaterialApp.router(locale: const Locale('es'))`) — matched here rather
/// than read from the OS, since there's no `BuildContext` in a background
/// isolate to resolve one through anyway.
Future<void> _showForMessage(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('es'));
  final jobId = message.data['job_id'] as String?;
  final (title, body) = notificationTextFor(
    message.data['type'] as String?,
    l10n,
  );
  await plugin.show(
    // Same job's pushes replace each other's notification tile instead of
    // stacking — a job_event push superseding an earlier one for the same
    // job is more useful than a pile of stale ones.
    id: jobId?.hashCode ?? message.hashCode,
    title: title,
    body: body,
    notificationDetails: _notificationDetails,
    payload: jobId,
  );
}

/// Main-isolate half: plugin setup/permission requests/tap handling.
/// [firebaseMessagingBackgroundHandler] above is the separate,
/// background-isolate half that actually shows the notification when the
/// app is backgrounded or killed.
class PushNotifications implements NotificationPermissionRequester {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set once the app's `GoRouter` exists (`main.dart`'s
  /// `_TheCraneAppState.initState`) — [init] itself runs before the router
  /// does, in `main()`, so tap handling can't target it directly at that
  /// point; a mutable field lets the two wire up independently.
  void Function()? onNotificationTap;

  /// Registers the Android notification channel and the plugin's tap
  /// callback. Call once, in `main()`, before `runApp`.
  ///
  /// Deliberately doesn't request any permission here — that's
  /// [requestPermission], called on-demand from `DriverHomeCubit
  /// .toggleAvailability` instead, same "ask when it's actually needed"
  /// pattern as `LocationSource.requestPermission`.
  Future<void> init() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
    );
  }

  /// TRK-3: iOS's alert/sound/badge prompt (`FirebaseMessaging.instance
  /// .requestPermission`) plus Android 13+'s runtime notifications
  /// permission (`flutter_local_notifications`' own API — distinct from,
  /// and in addition to, the `POST_NOTIFICATIONS` manifest entry TRK-5
  /// already declared for the location foreground service's own ongoing
  /// notification). Never throws: a denial just means a killed-app push
  /// won't surface anything later, which shouldn't block the caller (going
  /// available) from proceeding.
  @override
  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}
