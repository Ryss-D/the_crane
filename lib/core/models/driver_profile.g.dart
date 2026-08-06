// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DriverProfile _$DriverProfileFromJson(Map<String, dynamic> json) =>
    _DriverProfile(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      status: $enumDecode(_$DriverStatusEnumMap, json['status']),
      verified: json['verified'] as bool,
      licenseUrl: json['license_url'] as String?,
      truckPhotoUrl: json['truck_photo_url'] as String?,
      truck: json['truck'] == null
          ? null
          : Truck.fromJson(json['truck'] as Map<String, dynamic>),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$DriverProfileToJson(_DriverProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'status': _$DriverStatusEnumMap[instance.status]!,
      'verified': instance.verified,
      'license_url': instance.licenseUrl,
      'truck_photo_url': instance.truckPhotoUrl,
      'truck': instance.truck?.toJson(),
      'rating_avg': instance.ratingAvg,
    };

const _$DriverStatusEnumMap = {
  DriverStatus.offline: 'offline',
  DriverStatus.available: 'available',
  DriverStatus.onJob: 'on_job',
  DriverStatus.blocked: 'blocked',
};
