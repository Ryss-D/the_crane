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
  /// `delivered` has no next value here (CUS-5/LED-1): the backend firmly
  /// restricts `delivered → completed` to the job's customer alone
  /// (`confirm-delivery`, cash-payment confirmation) — the driver's last
  /// self-service action is reaching `delivered`, after which the UI shows
  /// an informational "waiting for the customer to confirm" state instead
  /// of an advance button (see `ActiveJobScreen`).
  JobStatus? get nextDriverStatus => switch (this) {
        JobStatus.assigned => JobStatus.enRoutePickup,
        JobStatus.enRoutePickup => JobStatus.arrivedPickup,
        JobStatus.arrivedPickup => JobStatus.loading,
        JobStatus.loading => JobStatus.inTransit,
        JobStatus.inTransit => JobStatus.delivered,
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

/// DRV-3: the symmetric customer summary `JobDriverSummary` never had a
/// counterpart for — backs the driver app's call-customer button. Matches
/// the backend's `JobCustomerInfo` (`backend/app/schemas/job.py`)
/// field-for-field: deliberately minimal, no rating/photo (there's no
/// equivalent for a customer the way there is for a driver).
@freezed
abstract class JobCustomerSummary with _$JobCustomerSummary {
  const factory JobCustomerSummary({
    required String id,
    String? name,
    String? phone,
  }) = _JobCustomerSummary;

  factory JobCustomerSummary.fromJson(Map<String, dynamic> json) =>
      _$JobCustomerSummaryFromJson(json);
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
    // DRV-3: symmetric to `driver` above — backs the call-customer button
    // on the driver's active-job screen. Optional for the same reason
    // `shareToken` is: older fake seed data predates this field.
    JobCustomerSummary? customer,
    required DateTime requestedAt,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
    // CUS-4: backs the "share trip" button (TRK-6's GET /v1/track/{token}).
    // Optional because the fake job history's older seed data predates this
    // field — real jobs always have one (the backend defaults it at creation).
    String? shareToken,
    // DRV-4: the real commission accrued at completion (backend's
    // JobRead.driver_commission, LED-1's DriverLedgerEntry) -- null until the
    // job is actually completed. ActiveJobScreen falls back to a client-side
    // flat-15% approximation only when this is null.
    int? driverCommission,
    // PAY-4: the Wompi checkout URL to redirect the customer to, present
    // only on the exact `confirmDelivery` response that just started a
    // digital-fare payment (PSE/card -- null for Nequi, and for every other
    // response, including a re-fetch of the same job afterward). Not a
    // real job field on the backend -- see `JobRead.async_payment_url`'s
    // doc comment (`backend/app/schemas/job.py`).
    String? asyncPaymentUrl,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
