import 'package:freezed_annotation/freezed_annotation.dart';

import 'truck.dart';

part 'driver_profile.freezed.dart';
part 'driver_profile.g.dart';

/// Driver presence state. Mirrors the backend `driver_profiles.status` column.
@JsonEnum(valueField: 'wire')
enum DriverStatus {
  offline('offline'),
  available('available'),
  onJob('on_job');

  const DriverStatus(this.wire);

  /// Snake_case value used on the wire.
  final String wire;
}

/// Driver profile as returned by the drivers API
/// (`POST /v1/drivers/me/register`, `PATCH /v1/drivers/me/status`).
///
/// Mirrors `backend/app/schemas/driver.py::DriverProfileRead` exactly: truck
/// info is nested under [truck] (a separate `trucks` row), not flattened
/// here — an earlier version of this model had flat `truckPlate`/
/// `truckType`/`capacity` fields, which silently parsed to null against the
/// real backend since the response actually nests them (same class of bug
/// `AppUser.name`/`phone` hit and got fixed for earlier in the project).
@freezed
abstract class DriverProfile with _$DriverProfile {
  const factory DriverProfile({
    String? id,
    required String userId,
    required DriverStatus status,
    required bool verified,
    String? licenseUrl,
    String? truckPhotoUrl,
    Truck? truck,
    @Default(0) double ratingAvg,
  }) = _DriverProfile;

  factory DriverProfile.fromJson(Map<String, dynamic> json) =>
      _$DriverProfileFromJson(json);
}
