import 'package:freezed_annotation/freezed_annotation.dart';

import 'lat_lng.dart';
import 'truck.dart';

part 'job.freezed.dart';
part 'job.g.dart';

/// Job lifecycle state. Mirrors the backend state machine (JOB-3) exactly:
///
/// ```
/// requested → matching → assigned → en_route_pickup → arrived_pickup
///                → loading → in_transit → delivered → completed
/// ```
/// plus the terminal side states `cancelled` and `no_drivers`.
@JsonEnum(valueField: 'wire')
enum JobStatus {
  requested('requested'),
  matching('matching'),
  assigned('assigned'),
  enRoutePickup('en_route_pickup'),
  arrivedPickup('arrived_pickup'),
  loading('loading'),
  inTransit('in_transit'),
  delivered('delivered'),
  completed('completed'),
  cancelled('cancelled'),
  noDrivers('no_drivers');

  const JobStatus(this.wire);

  /// Snake_case value used on the wire.
  final String wire;
}

/// Conveniences over the JOB-3 state machine, mirrored client-side.
extension JobStatusX on JobStatus {
  /// True once the job can no longer change state.
  bool get isTerminal =>
      this == JobStatus.completed ||
      this == JobStatus.cancelled ||
      this == JobStatus.noDrivers;

  /// The next state the assigned driver advances to from this one, or null
  /// when the driver has no forward action.
  ///
  /// `delivered → completed` is included so the DRV-3 skeleton can cycle the
  /// whole machine locally.
  /// TODO(CUS-5): completion becomes the customer's cash confirmation once
  /// the ledger lands; remove it from the driver cycle then.
  JobStatus? get nextDriverStatus => switch (this) {
        JobStatus.assigned => JobStatus.enRoutePickup,
        JobStatus.enRoutePickup => JobStatus.arrivedPickup,
        JobStatus.arrivedPickup => JobStatus.loading,
        JobStatus.loading => JobStatus.inTransit,
        JobStatus.inTransit => JobStatus.delivered,
        JobStatus.delivered => JobStatus.completed,
        _ => null,
      };
}

/// Kind of vehicle the customer needs towed. Mirrors backend `vehicle_type`.
@JsonEnum(valueField: 'wire')
enum VehicleType {
  moto('moto'),
  car('car'),
  suv('suv');

  const VehicleType(this.wire);

  /// Value used on the wire.
  final String wire;
}

/// Compact driver info embedded in a job payload for the customer UI
/// (CUS-3 driver card: name, plate, truck type, rating, photo).
@freezed
abstract class JobDriverSummary with _$JobDriverSummary {
  const factory JobDriverSummary({
    required String id,
    required String name,
    String? phone,
    required String truckPlate,
    TruckType? truckType,
    @Default(0) double ratingAvg,
    String? photoUrl,
  }) = _JobDriverSummary;

  factory JobDriverSummary.fromJson(Map<String, dynamic> json) =>
      _$JobDriverSummaryFromJson(json);
}

/// A tow job, as returned by `GET /v1/jobs/{id}` (JOB-1 / PLAN §2.2).
@freezed
abstract class Job with _$Job {
  const factory Job({
    required String id,
    required String customerId,
    String? driverId,
    required JobStatus status,
    required VehicleType vehicleType,
    required LatLng pickup,
    required String pickupAddress,
    required LatLng dropoff,
    required String dropoffAddress,
    required double distanceKm,
    required int quotedPrice,
    int? finalPrice,
    @Default('cash') String paymentMethod,
    JobDriverSummary? driver,
    required DateTime requestedAt,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
