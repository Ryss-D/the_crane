import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/location/location_source.dart';
import '../../../core/models/driver_profile.dart';

part 'driver_home_cubit.freezed.dart';

/// DRV-1 state: availability plus the last profile the backend returned.
@freezed
abstract class DriverHomeState with _$DriverHomeState {
  const DriverHomeState._();

  const factory DriverHomeState({
    @Default(DriverStatus.offline) DriverStatus status,
    @Default(false) bool isUpdating,
    DriverProfile? profile,
  }) = _DriverHomeState;

  /// Blocked from receiving offers (DRV-1 banner) — either not yet verified
  /// (AUTH-5) or on an admin hold (ADM-2's `DriverStatus.blocked`).
  ///
  /// TODO(LED-2): the settlement balance-cap rejection is a distinct third
  /// reason (`PATCH /v1/drivers/me/status` 403 "Balance owed to the platform
  /// exceeds the allowed cap"), but `toggleAvailability` currently discards
  /// that error entirely rather than capturing it into state — needs that
  /// plumbing before this banner can distinguish it from the two below.
  bool get isBlocked =>
      profile != null &&
      (!profile!.verified || profile!.status == DriverStatus.blocked);

  /// Which blocked-banner message to show — only meaningful when [isBlocked].
  DriverBlockReason get blockReason {
    final p = profile;
    if (p == null) return DriverBlockReason.none;
    if (!p.verified) return DriverBlockReason.unverified;
    if (p.status == DriverStatus.blocked) return DriverBlockReason.adminBlocked;
    return DriverBlockReason.none;
  }
}

enum DriverBlockReason { none, unverified, adminBlocked }

/// Drives the DRV-1 availability toggle through [DriversRepository].
class DriverHomeCubit extends Cubit<DriverHomeState> {
  DriverHomeCubit({
    required DriversRepository driversRepository,
    LocationSource? locationSource,
  })  : _repo = driversRepository,
        _locationSource = locationSource,
        super(const DriverHomeState());

  final DriversRepository _repo;
  final LocationSource? _locationSource;

  /// Flips available/offline via `PATCH /v1/drivers/me/status`.
  ///
  /// Requests location permission up front when going available (TRK-5) —
  /// better to ask now than mid-job — and takes one fix to send as `lat`/
  /// `lng`, which the backend requires to seed the Redis geo entry (422
  /// without them). The ongoing position *stream* only starts once a job is
  /// active (`ActiveJobCubit`), since the backend only accepts a driver's
  /// `location` message while one is assigned; this is just the one-shot
  /// fix availability itself needs.
  Future<void> toggleAvailability() async {
    if (state.isUpdating) return;
    final target = state.status == DriverStatus.available
        ? DriverStatus.offline
        : DriverStatus.available;
    emit(state.copyWith(isUpdating: true));
    double? lat;
    double? lng;
    if (target == DriverStatus.available) {
      final source = _locationSource;
      if (source != null && await source.requestPermission()) {
        final fix = await source.getCurrentPosition();
        lat = fix.lat;
        lng = fix.lng;
      }
    }
    try {
      final profile = await _repo.setStatus(target, lat: lat, lng: lng);
      emit(state.copyWith(
        status: profile.status,
        profile: profile,
        isUpdating: false,
      ));
    } catch (_) {
      emit(state.copyWith(isUpdating: false));
    }
  }
}
