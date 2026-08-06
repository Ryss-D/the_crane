import 'package:flutter/material.dart';

import '../../core/models/driver_profile.dart';
import '../../core/models/job.dart';
import '../../core/models/truck.dart';
import '../../l10n/app_localizations.dart';

/// Localized display labels for domain enums. All user-facing enum text goes
/// through here so nothing wire-level leaks into the UI.
extension JobStatusLabel on JobStatus {
  String label(AppLocalizations l10n) => switch (this) {
        JobStatus.requested => l10n.statusRequested,
        JobStatus.matching => l10n.statusMatching,
        JobStatus.assigned => l10n.statusAssigned,
        JobStatus.enRoutePickup => l10n.statusEnRoutePickup,
        JobStatus.arrivedPickup => l10n.statusArrivedPickup,
        JobStatus.loading => l10n.statusLoading,
        JobStatus.inTransit => l10n.statusInTransit,
        JobStatus.delivered => l10n.statusDelivered,
        JobStatus.completed => l10n.statusCompleted,
        JobStatus.cancelled => l10n.statusCancelled,
        JobStatus.noDrivers => l10n.statusNoDrivers,
      };

  /// Label for the DRV-3 button that advances *to* this status.
  String advanceActionLabel(AppLocalizations l10n) => switch (this) {
        JobStatus.enRoutePickup => l10n.advanceEnRoutePickup,
        JobStatus.arrivedPickup => l10n.advanceArrivedPickup,
        JobStatus.loading => l10n.advanceLoading,
        JobStatus.inTransit => l10n.advanceInTransit,
        JobStatus.delivered => l10n.advanceDelivered,
        JobStatus.completed => l10n.advanceCompleted,
        _ => label(l10n),
      };
}

extension VehicleTypeLabel on VehicleType {
  String label(AppLocalizations l10n) => switch (this) {
        VehicleType.moto => l10n.vehicleMoto,
        VehicleType.car => l10n.vehicleCar,
        VehicleType.suv => l10n.vehicleSuv,
      };

  IconData get icon => switch (this) {
        VehicleType.moto => Icons.two_wheeler,
        VehicleType.car => Icons.directions_car,
        VehicleType.suv => Icons.airport_shuttle,
      };
}

extension TruckTypeLabel on TruckType {
  String label(AppLocalizations l10n) => switch (this) {
        TruckType.motoOnly => l10n.truckTypeMotoOnly,
        TruckType.car => l10n.truckTypeCar,
        TruckType.flatbed => l10n.truckTypeFlatbed,
      };
}

extension TruckCapacityLabel on TruckCapacity {
  String label(AppLocalizations l10n) => switch (this) {
        TruckCapacity.moto => l10n.capacityMoto,
        TruckCapacity.car => l10n.capacityCar,
        TruckCapacity.both => l10n.capacityBoth,
      };
}

extension DriverStatusLabel on DriverStatus {
  String label(AppLocalizations l10n) => switch (this) {
        DriverStatus.offline => l10n.availabilityOffline,
        DriverStatus.available => l10n.availabilityAvailable,
        DriverStatus.onJob => l10n.availabilityOnJob,
      };
}

/// FLT-3: per-truck status at a glance in "Mi flota". "Unassigned" is
/// purely client-side (`driverId == null`, no `driver_status` to read yet);
/// the other three map directly from `Truck.driverStatus` (populated only
/// by `GET /v1/fleets/me` — see `Truck`'s doc comment).
extension TruckFleetStatusLabel on Truck {
  String fleetStatusLabel(AppLocalizations l10n) {
    if (driverId == null) return l10n.fleetTruckStatusUnassigned;
    return (driverStatus ?? DriverStatus.offline).label(l10n);
  }
}
