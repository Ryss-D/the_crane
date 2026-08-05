import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';

/// TRK-5: the driver's live GPS position, abstracted so
/// [ActiveJobCubit]/[DriverHomeCubit] don't depend on `geolocator` directly
/// — tests inject a fake stream instead of needing a real device/simulator.
abstract class LocationSource {
  /// True once permission is granted and location services are on. Requests
  /// permission if not already decided; does not prompt for "always" access
  /// — the driver only streams a position while the app is open and a job is
  /// active (see `ActiveJobCubit`'s `_activeDriverStatuses`), so "when in
  /// use" is enough for this MVP. True background (screen-off) tracking is a
  /// separate iOS entitlement request + device testing pass, not yet done.
  Future<bool> requestPermission();

  /// Live position fixes. Callers should have called [requestPermission]
  /// first; an unauthorized stream simply never emits.
  Stream<LatLng> watchPosition();
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
  Stream<LatLng> watchPosition() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters — avoid flooding the socket while stationary
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => LatLng(lat: p.latitude, lng: p.longitude));
  }
}
