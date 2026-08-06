// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'truck.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Truck _$TruckFromJson(Map<String, dynamic> json) => _Truck(
  id: json['id'] as String,
  driverId: json['driver_id'] as String?,
  fleetId: json['fleet_id'] as String?,
  plate: json['plate'] as String,
  type: $enumDecode(_$TruckTypeEnumMap, json['type']),
  capacity: $enumDecode(_$TruckCapacityEnumMap, json['capacity']),
  make: json['make'] as String?,
  model: json['model'] as String?,
);

Map<String, dynamic> _$TruckToJson(_Truck instance) => <String, dynamic>{
  'id': instance.id,
  'driver_id': instance.driverId,
  'fleet_id': instance.fleetId,
  'plate': instance.plate,
  'type': _$TruckTypeEnumMap[instance.type]!,
  'capacity': _$TruckCapacityEnumMap[instance.capacity]!,
  'make': instance.make,
  'model': instance.model,
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
