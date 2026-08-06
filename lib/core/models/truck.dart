import 'package:freezed_annotation/freezed_annotation.dart';

import 'driver_profile.dart';

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
/// Kept fleet-ready: `driverId` is the driver currently operating it,
/// `fleetId` is the owning fleet once FLT-1 lands (both nullable from day
/// one — see `backend/app/schemas/driver.py::TruckRead` — so attaching a
/// fleet later never needs a migration on this table).
///
/// [driverStatus]/[driverName] (FLT-3) are `null` by default — they're only
/// ever populated by `GET /v1/fleets/me`'s per-truck rollup (the fleet
/// owner's "Mi flota" screen), which is the one place a caller looks at
/// someone else's truck+driver together. Every other endpoint that returns
/// a `Truck` (e.g. `DriverProfile.truck`) leaves them null.
@freezed
abstract class Truck with _$Truck {
  const factory Truck({
    required String id,
    String? driverId,
    String? fleetId,
    required String plate,
    required TruckType type,
    required TruckCapacity capacity,
    String? make,
    String? model,
    DriverStatus? driverStatus,
    String? driverName,
  }) = _Truck;

  factory Truck.fromJson(Map<String, dynamic> json) => _$TruckFromJson(json);
}
