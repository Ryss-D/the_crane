import 'package:freezed_annotation/freezed_annotation.dart';

part 'lat_lng.freezed.dart';
part 'lat_lng.g.dart';

/// A WGS84 coordinate pair, as serialized by the backend
/// (`{"lat": 6.2442, "lng": -75.5812}`).
///
/// TODO(FND-6): once google_maps_flutter is wired, add converters to/from the
/// plugin's own LatLng type (import that one with an alias).
@freezed
abstract class LatLng with _$LatLng {
  const factory LatLng({
    required double lat,
    required double lng,
  }) = _LatLng;

  factory LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);
}
