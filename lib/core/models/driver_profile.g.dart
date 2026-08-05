// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DriverProfile _$DriverProfileFromJson(Map<String, dynamic> json) =>
    _DriverProfile(
      userId: json['user_id'] as String,
      status: $enumDecode(_$DriverStatusEnumMap, json['status']),
      verified: json['verified'] as bool,
      licenseUrl: json['license_url'] as String?,
      truckPlate: json['truck_plate'] as String?,
      truckType: $enumDecodeNullable(_$TruckTypeEnumMap, json['truck_type']),
      capacity: $enumDecodeNullable(_$TruckCapacityEnumMap, json['capacity']),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$DriverProfileToJson(_DriverProfile instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'status': _$DriverStatusEnumMap[instance.status]!,
      'verified': instance.verified,
      'license_url': instance.licenseUrl,
      'truck_plate': instance.truckPlate,
      'truck_type': _$TruckTypeEnumMap[instance.truckType],
      'capacity': _$TruckCapacityEnumMap[instance.capacity],
      'rating_avg': instance.ratingAvg,
    };

const _$DriverStatusEnumMap = {
  DriverStatus.offline: 'offline',
  DriverStatus.available: 'available',
  DriverStatus.onJob: 'on_job',
};

const _$TruckTypeEnumMap = {
  TruckType.motoOnly: 'moto_only',
  TruckType.car: 'car',
  TruckType.flatbed: 'flatbed',
};

const _$TruckCapacityEnumMap = {
  TruckCapacity.moto: 'moto',
  TruckCapacity.car: 'car',
  TruckCapacity.both: 'both',
};
