import 'package:freezed_annotation/freezed_annotation.dart';

import 'job.dart';

part 'saved_vehicle.freezed.dart';
part 'saved_vehicle.g.dart';

/// A customer's saved vehicle (CUS-6), matching the `vehicles` API contract
/// exactly:
/// ```
/// GET  /v1/me/vehicles       -> [SavedVehicle]
/// POST /v1/me/vehicles       {type, make?, model?, plate} -> SavedVehicle
/// PATCH /v1/me/vehicles/{id} any subset of {type, make, model, plate}
/// DELETE /v1/me/vehicles/{id} -> 204
/// ```
/// Reuses the existing [VehicleType] enum/wire-mapping from `job.dart` —
/// there is no separate vehicle-type concept for saved vehicles.
@freezed
abstract class SavedVehicle with _$SavedVehicle {
  const factory SavedVehicle({
    required String id,
    required VehicleType type,
    String? make,
    String? model,
    required String plate,
  }) = _SavedVehicle;

  factory SavedVehicle.fromJson(Map<String, dynamic> json) =>
      _$SavedVehicleFromJson(json);
}
