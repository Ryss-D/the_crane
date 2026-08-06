import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/location/location_source.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/ws/crane_socket.dart';

part 'active_job_cubit.freezed.dart';

/// DRV-3 state: the driver's active job plus the last backend rejection
/// message from `advance()`, if any (409/403 — see
/// `JobStatusRejectedException`). [errorMessage] is transient: it's cleared
/// the moment another `advance()` attempt starts.
@freezed
abstract class ActiveJobState with _$ActiveJobState {
  const factory ActiveJobState({
    Job? job,
    String? errorMessage,
  }) = _ActiveJobState;
}

/// DRV-3 skeleton — holds the driver's active job and advances the JOB-3
/// state machine via `POST /v1/jobs/{id}/status`.
///
/// Provided at the driver shell so the job survives navigation between home
/// and the active job screen. While a [socket] is wired and the job is in
/// one of the backend's "active driver" statuses (mirrors
/// `ACTIVE_DRIVER_STATUSES` in `backend/app/api/ws.py`), this also pushes a
/// location fix over the WebSocket every [locationInterval] (TRK-2/TRK-4).
///
/// DRV-4: also subscribes to `JobsRepository.watchJob` (same pattern as
/// `RequestBloc._watch`) so a `delivered` job flipping to `completed` once
/// the *customer* confirms cash payment (CUS-5's `confirmDelivery` — the
/// driver has no equivalent action) is reflected here live, not just after
/// the driver's own `advance()` calls.
class ActiveJobCubit extends Cubit<ActiveJobState> {
  ActiveJobCubit({
    required JobsRepository jobsRepository,
    CraneSocket? socket,
    LocationSource? locationSource,
    this.locationInterval = const Duration(seconds: 5),
  })  : _repo = jobsRepository,
        _socket = socket,
        _locationSource = locationSource,
        super(const ActiveJobState());

  final JobsRepository _repo;
  final CraneSocket? _socket;
  final LocationSource? _locationSource;

  /// Injectable so tests don't wait 5 real seconds between fixes.
  final Duration locationInterval;

  bool _advancing = false;
  bool _cancelling = false;
  Timer? _locationTimer;
  StreamSubscription<LatLng>? _positionSub;
  LatLng? _lastFix;
  StreamSubscription<Job>? _jobSub;

  /// Statuses in which the backend accepts a driver's WS `location` message
  /// (mirrors `ACTIVE_DRIVER_STATUSES` server-side).
  static const _activeDriverStatuses = {
    JobStatus.assigned,
    JobStatus.enRoutePickup,
    JobStatus.arrivedPickup,
    JobStatus.loading,
    JobStatus.inTransit,
  };

  /// Set right after an accepted offer (see `OfferCubit.accept`).
  void start(Job job) {
    emit(ActiveJobState(job: job));
    _syncLocationTimer(job);
    _watch(job.id);
  }

  /// Mirrors `RequestBloc._watch`: (re)subscribes to the live job stream so
  /// this cubit reflects changes the driver didn't cause itself — chiefly
  /// the customer's CUS-5 `confirmDelivery` flipping `delivered` →
  /// `completed`.
  void _watch(String jobId) {
    _jobSub?.cancel();
    _jobSub = _repo.watchJob(jobId).listen((job) {
      if (isClosed) return;
      emit(state.copyWith(job: job));
      _syncLocationTimer(job);
    });
  }

  /// Advances to the next driver status; no-op when the job is terminal.
  ///
  /// DRV-3: a rejected transition (409/403 —
  /// [JobStatusRejectedException], thrown by both `JobsRepository`
  /// implementations) surfaces its message via [ActiveJobState.errorMessage]
  /// instead of failing silently; any other error is still swallowed, same
  /// as before.
  Future<void> advance() async {
    final job = state.job;
    final next = job?.status.nextDriverStatus;
    if (job == null || next == null || _advancing) return;
    _advancing = true;
    emit(state.copyWith(errorMessage: null));
    try {
      final updated = await _repo.updateJobStatus(job.id, next);
      emit(state.copyWith(job: updated));
      _syncLocationTimer(updated);
    } on JobStatusRejectedException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (_) {
      // Non-rejection failure (e.g. network) — nothing to surface yet.
    } finally {
      _advancing = false;
    }
  }

  /// DRV-3: the driver bails on the job before `loading` starts — the
  /// backend releases it back to the pool (`matching`) rather than marking
  /// it `cancelled` (that terminal status, and the grace-period nuance, are
  /// customer-only — see `DRIVER_CANCELLABLE` in
  /// `backend/app/services/jobs.py`). A rejection (already past
  /// `arrived_pickup`) surfaces the same way [advance]'s does.
  ///
  /// Clears the local job/location-tracking state on success, same as
  /// [clear] — there's nothing left for this screen to show once the job no
  /// longer belongs to this driver.
  Future<void> cancel() async {
    final job = state.job;
    if (job == null || _cancelling) return;
    _cancelling = true;
    emit(state.copyWith(errorMessage: null));
    try {
      await _repo.cancelJob(job.id, asDriver: true);
      _stopLocationTracking();
      _jobSub?.cancel();
      _jobSub = null;
      emit(const ActiveJobState());
    } on JobStatusRejectedException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (_) {
      // Non-rejection failure (e.g. network) — nothing to surface yet, same
      // convention as advance().
    } finally {
      _cancelling = false;
    }
  }

  /// Starts/stops the periodic `sendLocation` push to match the job's
  /// current status. A no-op when no socket was wired (fakes, or tests that
  /// don't care about TRK-4).
  void _syncLocationTimer(Job job) {
    final socket = _socket;
    if (socket == null || !_activeDriverStatuses.contains(job.status)) {
      _stopLocationTracking();
      return;
    }
    _positionSub ??= _locationSource?.watchPosition().listen((fix) {
      _lastFix = fix;
    });
    _locationTimer ??= Timer.periodic(locationInterval, (_) {
      final current = state.job;
      if (current == null) return;
      // Prefer the live GPS fix; fall back to the job's pickup point when no
      // LocationSource was wired (fakes, or tests that don't care about
      // TRK-5) so the WS `location` message keeps flowing either way.
      final fix = _lastFix ?? current.pickup;
      socket.sendLocation(current.id, fix.lat, fix.lng);
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _lastFix = null;
  }

  /// Clears the finished job when the driver returns home.
  void clear() {
    emit(const ActiveJobState());
    _stopLocationTracking();
    _jobSub?.cancel();
    _jobSub = null;
  }

  @override
  Future<void> close() {
    _stopLocationTracking();
    _jobSub?.cancel();
    return super.close();
  }
}
