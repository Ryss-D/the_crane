// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_prediction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlacePrediction _$PlacePredictionFromJson(Map<String, dynamic> json) =>
    _PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$PlacePredictionToJson(_PlacePrediction instance) =>
    <String, dynamic>{
      'place_id': instance.placeId,
      'description': instance.description,
    };

_PlaceDetails _$PlaceDetailsFromJson(Map<String, dynamic> json) =>
    _PlaceDetails(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      formattedAddress: json['formatted_address'] as String,
    );

Map<String, dynamic> _$PlaceDetailsToJson(_PlaceDetails instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'formatted_address': instance.formattedAddress,
    };
