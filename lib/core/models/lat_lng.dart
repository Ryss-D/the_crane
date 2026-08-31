import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

part 'lat_lng.freezed.dart';
part 'lat_lng.g.dart';

/// A WGS84 coordinate pair, as serialized by the backend
/// (`{"lat": 6.2442, "lng": -75.5812}`).
@freezed
abstract class LatLng with _$LatLng {
  const factory LatLng({
    required double lat,
    required double lng,
  }) = _LatLng;

  factory LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);
}

/// FND-6: converts to `google_maps_flutter`'s own `LatLng` type (imported
/// above as `gmaps.LatLng` to avoid colliding with this app's [LatLng]) at
/// the one boundary that needs it — map widgets (`CraneMap` and friends).
/// Everywhere else in the app keeps using this app's own [LatLng].
extension LatLngGoogleMapsX on LatLng {
  gmaps.LatLng toGoogleMaps() => gmaps.LatLng(lat, lng);
}

/// The reverse of [LatLngGoogleMapsX] — for a drag callback handing back a
/// `gmaps.LatLng` (see `CraneMapMarker.onDragEnd`).
extension GoogleMapsLatLngX on gmaps.LatLng {
  LatLng toAppLatLng() => LatLng(lat: latitude, lng: longitude);
}
