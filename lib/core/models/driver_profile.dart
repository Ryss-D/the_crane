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
/// (`PATCH /v1/drivers/me/status`).
@freezed
abstract class DriverProfile with _$DriverProfile {
  const factory DriverProfile({
    required String userId,
    required DriverStatus status,
    required bool verified,
    String? licenseUrl,
    String? truckPlate,
    TruckType? truckType,
    TruckCapacity? capacity,
    @Default(0) double ratingAvg,
  }) = _DriverProfile;

  factory DriverProfile.fromJson(Map<String, dynamic> json) =>
      _$DriverProfileFromJson(json);
}
