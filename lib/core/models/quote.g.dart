// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Quote _$QuoteFromJson(Map<String, dynamic> json) => _Quote(
  quoteId: json['quote_id'] as String,
  vehicleType: $enumDecode(_$VehicleTypeEnumMap, json['vehicle_type']),
  price: (json['price'] as num).toInt(),
  currency: json['currency'] as String? ?? 'COP',
  etaMinutes: (json['eta_minutes'] as num).toInt(),
  distanceKm: (json['distance_km'] as num).toDouble(),
  expiresAt: json['expires_at'] == null
      ? null
      : DateTime.parse(json['expires_at'] as String),
);

Map<String, dynamic> _$QuoteToJson(_Quote instance) => <String, dynamic>{
  'quote_id': instance.quoteId,
  'vehicle_type': _$VehicleTypeEnumMap[instance.vehicleType]!,
  'price': instance.price,
  'currency': instance.currency,
  'eta_minutes': instance.etaMinutes,
  'distance_km': instance.distanceKm,
  'expires_at': instance.expiresAt?.toIso8601String(),
};

const _$VehicleTypeEnumMap = {
  VehicleType.moto: 'moto',
  VehicleType.car: 'car',
  VehicleType.suv: 'suv',
};
