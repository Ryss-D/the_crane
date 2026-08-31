import 'package:dio/dio.dart';

import '../models/place_prediction.dart';

/// FND-6 — address search for the CUS-1 request screen, proxied through the
/// backend (`GET /v1/places/autocomplete`, `GET /v1/places/details/{id}`)
/// rather than calling Google directly: an Android/iOS *app-restricted*
/// Maps key only authenticates through the native Maps SDK's own
/// attestation, not a plain REST call from Dart — so Places has to go
/// through a server-side key instead (`backend/app/services/pricing.py`'s
/// `GoogleDirectionsClient` already does the same thing for Directions).
///
/// Implementations: [ApiPlacesRepository] (dio -> FastAPI) and
/// `FakePlacesRepository`. The composition root in `lib/app/di.dart` picks
/// one from `Env.useFakeBackend`.
abstract interface class PlacesRepository {
  /// `GET /v1/places/autocomplete?input=..` — empty list if [input] is too
  /// short to be worth querying, or if the backend has no Google Maps key
  /// configured yet (never an error either way; the request screen falls
  /// back to manual text entry).
  Future<List<PlacePrediction>> autocomplete(String input);

  /// `GET /v1/places/details/{placeId}` — real coordinates + formatted
  /// address for a prediction the customer picked.
  Future<PlaceDetails> placeDetails(String placeId);

  /// `GET /v1/places/geocode?lat=&lng=` (CUS-1/CUS-4/WEB-2 follow-up) — a
  /// human-readable address for a raw coordinate (a dragged pin), or `null`
  /// if the backend has no Google Maps key configured yet or Google itself
  /// errors. Never throws: unlike [placeDetails] (which has nothing sensible
  /// to fall back to for a specific place_id), a caller here always has the
  /// pre-existing raw-coordinate text to fall back to, so this degrades the
  /// same "silent, never surfaces as an error" way [autocomplete] does.
  Future<String?> reverseGeocode(double lat, double lng);
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiPlacesRepository implements PlacesRepository {
  ApiPlacesRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<PlacePrediction>> autocomplete(String input) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/places/autocomplete',
      queryParameters: {'input': input},
    );
    final predictions = res.data!['predictions'] as List;
    return predictions
        .cast<Map<String, dynamic>>()
        .map(PlacePrediction.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PlaceDetails> placeDetails(String placeId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/places/details/$placeId',
    );
    return PlaceDetails.fromJson(res.data!);
  }

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/places/geocode',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      return res.data!['address'] as String?;
    } on DioException {
      // 503 (no server-side key configured, or Google itself errored) is the
      // expected failure mode -- mirrors ApiDirectionsRepository.route's own
      // 503 handling. Any other DioException (timeout, no connectivity) gets
      // the same graceful-degradation treatment: there is no error UI for
      // this best-effort enrichment, only the pre-existing raw-coordinate
      // text the caller already falls back to.
      return null;
    }
  }
}
