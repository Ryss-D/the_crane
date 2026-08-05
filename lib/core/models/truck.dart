import 'package:freezed_annotation/freezed_annotation.dart';

part 'truck.freezed.dart';
part 'truck.g.dart';

/// Tow-truck kind. Mirrors the backend `trucks.type` column exactly.
@JsonEnum(valueField: 'wire')
enum TruckType {
  motoOnly('moto_only'),
  car('car'),
  flatbed('flatbed');

  const TruckType(this.wire);

  /// Snake_case value used on the wire.
  final String wire;
}

/// What a truck can haul. Mirrors the backend `trucks.capacity` column.
@JsonEnum(valueField: 'wire')
enum TruckCapacity {
  moto('moto'),
  car('car'),
  both('both');

  const TruckCapacity(this.wire);

  /// Value used on the wire.
  final String wire;
}

/// A tow truck registered on the platform (AUTH-5 `trucks` table).
///
/// Kept fleet-ready: `driverId` is the driver currently operating it, while
/// ownership (fleet owner) lives server-side.
@freezed
abstract class Truck with _$Truck {
  const factory Truck({
    required String id,
    String? driverId,
    required String plate,
    required TruckType type,
    required TruckCapacity capacity,
    String? make,
    String? model,
  }) = _Truck;

  factory Truck.fromJson(Map<String, dynamic> json) => _$TruckFromJson(json);
}
