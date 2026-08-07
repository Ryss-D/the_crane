import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/location/location_source.dart';
import '../../../core/models/driver_profile.dart';
import '../../../core/notifications/notification_permission_requester.dart';

part 'driver_home_cubit.freezed.dart';

/// DRV-1 state: availability plus the last profile the backend returned.
@freezed
abstract class DriverHomeState with _$DriverHomeState {
  const DriverHomeState._();

  const factory DriverHomeState({
    @Default(DriverStatus.offline) DriverStatus status,
    @Default(false) bool isUpdating,
    DriverProfile? profile,
    // The balance-cap rejection (`toggleAvailability`'s 403 "Balance owed to
    // the platform exceeds the allowed cap") isn't a stored profile field
    // like `verified`/`status` below — it only shows up as a failed
    // `setStatus(available)` attempt, so it needs its own slot. Cleared the
    // moment a toggle attempt starts, same lifecycle as
    // `ActiveJobState.errorMessage` (DRV-3).
    @Default(DriverBlockReason.none) DriverBlockReason lastToggleFailureReason,
  }) = _DriverHomeState;

  /// Blocked from receiving offers (DRV-1 banner) — not yet verified
  /// (AUTH-5), on an admin hold (ADM-2's `DriverStatus.blocked`), or the
  /// most recent toggle attempt was rejected for exceeding the settlement
  /// balance cap.
  bool get isBlocked =>
      lastToggleFailureReason != DriverBlockReason.none ||
      (profile != null &&
          (!profile!.verified || profile!.status == DriverStatus.blocked));

  /// Which blocked-banner message to show — only meaningful when [isBlocked].
  /// [lastToggleFailureReason] takes priority: it's the most recent signal,
  /// and the two profile-derived reasons below can't fire at the same time
  /// as a successful-enough-to-be-rejected toggle attempt anyway.
  DriverBlockReason get blockReason {
    if (lastToggleFailureReason != DriverBlockReason.none) {
      return lastToggleFailureReason;
    }
    final p = profile;
    if (p == null) return DriverBlockReason.none;
    if (!p.verified) return DriverBlockReason.unverified;
    if (p.status == DriverStatus.blocked) return DriverBlockReason.adminBlocked;
    return DriverBlockReason.none;
  }
}

enum DriverBlockReason { none, unverified, adminBlocked, balanceCap }

/// The exact backend `detail` string for the balance-cap rejection
/// (`backend/app/api/drivers.py`'s `update_driver_status`). Matched
/// verbatim rather than just keying off the 403 status code, since a
/// couple of other, unrelated checks also 403 on this same endpoint
/// ("Driver is not verified yet", "Driver is blocked").
const _balanceCapDetail = 'Balance owed to the platform exceeds the allowed cap';

/// Drives the DRV-1 availability toggle through [DriversRepository].
class DriverHomeCubit extends Cubit<DriverHomeState> {
  DriverHomeCubit({
    required DriversRepository driversRepository,
    LocationSource? locationSource,
    NotificationPermissionRequester? notificationPermissionRequester,
  })  : _repo = driversRepository,
        _locationSource = locationSource,
        _notificationPermissionRequester = notificationPermissionRequester,
        super(const DriverHomeState());

  final DriversRepository _repo;
  final LocationSource? _locationSource;
  final NotificationPermissionRequester? _notificationPermissionRequester;

  /// Flips available/offline via `PATCH /v1/drivers/me/status`.
  ///
  /// Requests location permission up front when going available (TRK-5) —
  /// better to ask now than mid-job — and takes one fix to send as `lat`/
  /// `lng`, which the backend requires to seed the Redis geo entry (422
  /// without them). The ongoing position *stream* only starts once a job is
  /// active (`ActiveJobCubit`), since the backend only accepts a driver's
  /// `location` message while one is assigned; this is just the one-shot
  /// fix availability itself needs.
  ///
  /// Also requests notification permission at the same moment (TRK-3) —
  /// same "ask when it's actually needed" reasoning: a driver who's never
  /// gone available has no offers to be notified about yet, so there's
  /// nothing to ask for before this point either.
  Future<void> toggleAvailability() async {
    if (state.isUpdating) return;
    final target = state.status == DriverStatus.available
        ? DriverStatus.offline
        : DriverStatus.available;
    emit(state.copyWith(
      isUpdating: true,
      lastToggleFailureReason: DriverBlockReason.none,
    ));
    double? lat;
    double? lng;
    if (target == DriverStatus.available) {
      final source = _locationSource;
      if (source != null && await source.requestPermission()) {
        final fix = await source.getCurrentPosition();
        lat = fix.lat;
        lng = fix.lng;
      }
      // TRK-3: best-effort — a denied/unavailable notification permission
      // doesn't block going available, it only means a killed-app push
      // won't be able to surface anything later.
      await _notificationPermissionRequester?.requestPermission();
    }
    try {
      final profile = await _repo.setStatus(target, lat: lat, lng: lng);
      emit(state.copyWith(
        status: profile.status,
        profile: profile,
        isUpdating: false,
      ));
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      emit(state.copyWith(
        isUpdating: false,
        lastToggleFailureReason: detail == _balanceCapDetail
            ? DriverBlockReason.balanceCap
            : DriverBlockReason.none,
      ));
    } catch (_) {
      emit(state.copyWith(isUpdating: false));
    }
  }
}
