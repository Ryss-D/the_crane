import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';

/// TRK-5: the driver's live GPS position, abstracted so
/// [ActiveJobCubit]/[DriverHomeCubit] don't depend on `geolocator` directly
/// — tests inject a fake stream instead of needing a real device/simulator.
abstract class LocationSource {
  /// True once permission is granted and location services are on. Requests
  /// permission if not already decided; does not prompt for "always" access
  /// on its own — that's [requestBackgroundPermission], called separately
  /// once a job actually starts (see `ActiveJobCubit.start`), so a driver who
  /// never accepts a job is never asked for more than "while in use".
  Future<bool> requestPermission();

  /// TRK-5: escalates an already-granted "while in use" permission to
  /// "always", so [watchPosition] keeps streaming once the app is
  /// backgrounded/the screen is locked during an active job. Callers should
  /// have called [requestPermission] first — this is a no-op (returns
  /// whatever the current permission already is) if it wasn't ["denied"].
  ///
  /// Never throws: a decline just means tracking degrades to
  /// foreground-only for this job, which shouldn't block the driver from
  /// working it — same "ask when needed, don't gate on the answer"
  /// convention as [requestPermission] and
  /// `PushNotifications.requestPermission`.
  ///
  /// On Android 11+, an app that's already been denied "Allow all the time"
  /// once cannot be re-prompted in-line — the OS requires the user to grant
  /// it from Settings instead. This still calls [Geolocator.requestPermission]
  /// (correct for the first ask, and for iOS's "upgrade to Always" prompt at
  /// any point), it just may not visibly prompt on a repeat Android denial.
  Future<bool> requestBackgroundPermission();

  /// Live position fixes. Callers should have called [requestPermission]
  /// first; an unauthorized stream simply never emits. While a job is
  /// active, keeps streaming in the background on Android (via a foreground
  /// service + persistent notification, per [requestBackgroundPermission])
  /// and on iOS (via the `UIBackgroundModes: [location]` + "Always"
  /// entitlement declared in `Info.plist`) whenever that permission was
  /// granted.
  Stream<LatLng> watchPosition();

  /// A single current fix — used where only one reading is needed (DRV-1's
  /// "going available" call, which must include `lat`/`lng`). Callers
  /// should have called [requestPermission] first.
  Future<LatLng> getCurrentPosition();
}

class GeolocatorLocationSource implements LocationSource {
  @override
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestBackgroundPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always;
  }

  @override
  Stream<LatLng> watchPosition() {
    return Geolocator.getPositionStream(locationSettings: _locationSettings())
        .map((p) => LatLng(lat: p.latitude, lng: p.longitude));
  }

  /// Platform-specific settings so an active job's tracking survives
  /// backgrounding: Android gets a foreground service (with the persistent
  /// notification Android requires while it runs) and iOS gets the
  /// background location indicator. Falls back to the plain cross-platform
  /// settings elsewhere (desktop/web, exercised only by fakes in tests).
  LocationSettings _locationSettings() {
    // meters — avoid flooding the socket/battery while stationary, same
    // distance filter as before this change on every platform.
    const distanceFilter = 10;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'The Crane — servicio activo',
          notificationText: 'Compartiendo tu ubicación mientras completas el servicio.',
          notificationChannelName: 'Ubicación en segundo plano',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<LatLng> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition();
    return LatLng(lat: position.latitude, lng: position.longitude);
  }
}
