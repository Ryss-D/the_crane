import 'package:dio/dio.dart';

import '../models/lat_lng.dart';

/// FND-6 — the route polyline drawn on the map (DRV-3's active job screen,
/// the RAT-3 trip-history detail screen), proxied through the backend
/// (`GET /v1/directions/route`) for the same app-restricted-key reason
/// [PlacesRepository] is: a raw REST call to Directions from Dart can't
/// authenticate with an Android/iOS-restricted key.
///
/// Implementations: [ApiDirectionsRepository] (dio -> FastAPI) and
/// `FakeDirectionsRepository` (a straight line between the two points).
abstract interface class DirectionsRepository {
  /// `GET /v1/directions/route` — real road-route points from [origin] to
  /// [destination], or a straight line if the backend has no Google Maps
  /// key configured yet (never an error; the map just draws a plainer
  /// line).
  Future<List<LatLng>> route({required LatLng origin, required LatLng destination});
}

/// Dio-backed implementation hitting the FastAPI v1 endpoint.
class ApiDirectionsRepository implements DirectionsRepository {
  ApiDirectionsRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<LatLng>> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/directions/route',
        queryParameters: {
          'origin_lat': origin.lat,
          'origin_lng': origin.lng,
          'dest_lat': destination.lat,
          'dest_lng': destination.lng,
        },
      );
      final points = res.data!['points'] as List;
      return points
          .cast<Map<String, dynamic>>()
          .map(LatLng.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      // 503: backend has no google_maps_api_key configured yet (mirrors
      // pricing.py's own haversine fallback) -- a straight line is a
      // reasonable degraded display, not worth surfacing as an error.
      if (e.response?.statusCode == 503) return [origin, destination];
      rethrow;
    }
  }
}
