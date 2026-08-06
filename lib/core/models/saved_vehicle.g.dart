// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_vehicle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavedVehicle _$SavedVehicleFromJson(Map<String, dynamic> json) =>
    _SavedVehicle(
      id: json['id'] as String,
      type: $enumDecode(_$VehicleTypeEnumMap, json['type']),
      make: json['make'] as String?,
      model: json['model'] as String?,
      plate: json['plate'] as String,
    );

Map<String, dynamic> _$SavedVehicleToJson(_SavedVehicle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$VehicleTypeEnumMap[instance.type]!,
      'make': instance.make,
      'model': instance.model,
      'plate': instance.plate,
    };

const _$VehicleTypeEnumMap = {
  VehicleType.moto: 'moto',
  VehicleType.car: 'car',
  VehicleType.suv: 'suv',
};
