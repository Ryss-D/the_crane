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
}
