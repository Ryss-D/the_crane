import 'package:freezed_annotation/freezed_annotation.dart';

part 'place_prediction.freezed.dart';
part 'place_prediction.g.dart';

/// One suggestion from `GET /v1/places/autocomplete` (FND-6) — the backend's
/// thin proxy over Google's Places Autocomplete API (see
/// `backend/app/api/places.py`). Selecting one resolves to real coordinates
/// via [PlaceDetails].
@freezed
abstract class PlacePrediction with _$PlacePrediction {
  const factory PlacePrediction({
    required String placeId,
    required String description,
  }) = _PlacePrediction;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) =>
      _$PlacePredictionFromJson(json);
}

/// `GET /v1/places/details/{placeId}` response: real coordinates plus a
/// human-readable address for a [PlacePrediction] the customer picked.
@freezed
abstract class PlaceDetails with _$PlaceDetails {
  const factory PlaceDetails({
    required double lat,
    required double lng,
    required String formattedAddress,
  }) = _PlaceDetails;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) =>
      _$PlaceDetailsFromJson(json);
}
