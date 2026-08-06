import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/location/location_source.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/ws/crane_socket.dart';

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
class ActiveJobCubit extends Cubit<Job?> {
  ActiveJobCubit({
    required JobsRepository jobsRepository,
    CraneSocket? socket,
    LocationSource? locationSource,
    this.locationInterval = const Duration(seconds: 5),
  })  : _repo = jobsRepository,
        _socket = socket,
        _locationSource = locationSource,
        super(null);

  final JobsRepository _repo;
  final CraneSocket? _socket;
  final LocationSource? _locationSource;

  /// Injectable so tests don't wait 5 real seconds between fixes.
  final Duration locationInterval;

  bool _advancing = false;
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
    emit(job);
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
      emit(job);
      _syncLocationTimer(job);
    });
  }

  /// Advances to the next driver status; no-op when the job is terminal.
  Future<void> advance() async {
    final job = state;
    final next = job?.status.nextDriverStatus;
    if (job == null || next == null || _advancing) return;
    _advancing = true;
    try {
      final updated = await _repo.updateJobStatus(job.id, next);
      emit(updated);
      _syncLocationTimer(updated);
    } catch (_) {
      // TODO(DRV-3): surface backend rejections (409/403) in the UI.
    } finally {
      _advancing = false;
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
      final current = state;
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
    emit(null);
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
