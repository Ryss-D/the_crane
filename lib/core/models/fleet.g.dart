// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fleet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Fleet _$FleetFromJson(Map<String, dynamic> json) => _Fleet(
  id: json['id'] as String,
  ownerUserId: json['owner_user_id'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  trucks:
      (json['trucks'] as List<dynamic>?)
          ?.map((e) => Truck.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Truck>[],
);

Map<String, dynamic> _$FleetToJson(_Fleet instance) => <String, dynamic>{
  'id': instance.id,
  'owner_user_id': instance.ownerUserId,
  'name': instance.name,
  'created_at': instance.createdAt.toIso8601String(),
  'trucks': instance.trucks.map((e) => e.toJson()).toList(),
};

_FleetMemberBalance _$FleetMemberBalanceFromJson(Map<String, dynamic> json) =>
    _FleetMemberBalance(
      driverId: json['driver_id'] as String,
      name: json['name'] as String?,
      owedBalance: (json['owed_balance'] as num).toInt(),
    );

Map<String, dynamic> _$FleetMemberBalanceToJson(_FleetMemberBalance instance) =>
    <String, dynamic>{
      'driver_id': instance.driverId,
      'name': instance.name,
      'owed_balance': instance.owedBalance,
    };

_FleetBalance _$FleetBalanceFromJson(Map<String, dynamic> json) =>
    _FleetBalance(
      fleetId: json['fleet_id'] as String,
      owedBalance: (json['owed_balance'] as num).toInt(),
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (e) => FleetMemberBalance.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <FleetMemberBalance>[],
    );

Map<String, dynamic> _$FleetBalanceToJson(_FleetBalance instance) =>
    <String, dynamic>{
      'fleet_id': instance.fleetId,
      'owed_balance': instance.owedBalance,
      'members': instance.members.map((e) => e.toJson()).toList(),
    };
