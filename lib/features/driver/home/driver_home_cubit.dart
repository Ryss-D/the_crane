import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
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

  /// Blocked from receiving offers (DRV-1 banner).
  ///
  /// TODO(LED-1): also block on the commission balance cap once the driver
  /// ledger exists.
  bool get isBlocked => profile != null && !profile!.verified;
}

/// Drives the DRV-1 availability toggle through [DriversRepository].
class DriverHomeCubit extends Cubit<DriverHomeState> {
  DriverHomeCubit({required DriversRepository driversRepository})
      : _repo = driversRepository,
        super(const DriverHomeState());

  final DriversRepository _repo;

  /// Flips available/offline via `PATCH /v1/drivers/me/status`.
  ///
  /// TODO(TRK-5): going available must also start the foreground location
  /// stream once geolocator + the WebSocket are wired.
  Future<void> toggleAvailability() async {
    if (state.isUpdating) return;
    final target = state.status == DriverStatus.available
        ? DriverStatus.offline
        : DriverStatus.available;
    emit(state.copyWith(isUpdating: true));
    try {
      final profile = await _repo.setStatus(target);
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
