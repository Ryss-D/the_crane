// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_balance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Settlement _$SettlementFromJson(Map<String, dynamic> json) => _Settlement(
  id: json['id'] as String,
  amountCents: (json['amount_cents'] as num).toInt(),
  settledAt: DateTime.parse(json['settled_at'] as String),
  note: json['note'] as String?,
);

Map<String, dynamic> _$SettlementToJson(_Settlement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount_cents': instance.amountCents,
      'settled_at': instance.settledAt.toIso8601String(),
      'note': instance.note,
    };

_DriverBalance _$DriverBalanceFromJson(Map<String, dynamic> json) =>
    _DriverBalance(
      owedCents: (json['owed_cents'] as num).toInt(),
      balanceCapCents: (json['balance_cap_cents'] as num?)?.toInt(),
      recentSettlements:
          (json['recent_settlements'] as List<dynamic>?)
              ?.map((e) => Settlement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Settlement>[],
    );

Map<String, dynamic> _$DriverBalanceToJson(_DriverBalance instance) =>
    <String, dynamic>{
      'owed_cents': instance.owedCents,
      'balance_cap_cents': instance.balanceCapCents,
      'recent_settlements': instance.recentSettlements
          .map((e) => e.toJson())
          .toList(),
    };
