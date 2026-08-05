import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/ws/crane_socket.dart';

/// DRV-3 skeleton — holds the driver's active job and advances the JOB-3
/// state machine via `POST /v1/jobs/{id}/status`.
///
/// Provided at the driver shell so the job survives navigation between home
/// and the active job screen. While a [socket] is wired and the job is in
/// one of the backend's "active driver" statuses (mirrors
/// `ACTIVE_DRIVER_STATUSES` in `backend/app/api/ws.py`), this also pushes a
/// location fix over the WebSocket every [locationInterval] (TRK-2/TRK-4).
class ActiveJobCubit extends Cubit<Job?> {
  ActiveJobCubit({
    required JobsRepository jobsRepository,
    CraneSocket? socket,
    this.locationInterval = const Duration(seconds: 5),
  })  : _repo = jobsRepository,
        _socket = socket,
        super(null);

  final JobsRepository _repo;
  final CraneSocket? _socket;

  /// Injectable so tests don't wait 5 real seconds between fixes.
  final Duration locationInterval;

  bool _advancing = false;
  Timer? _locationTimer;

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
      _locationTimer?.cancel();
      _locationTimer = null;
      return;
    }
    _locationTimer ??= Timer.periodic(locationInterval, (_) {
      final current = state;
      if (current == null) return;
      // TODO(TRK-5): source the fix from geolocator's live position stream
      // instead of the job's own pickup point once it's wired — this keeps
      // the WS `location` message flowing end to end in the meantime.
      socket.sendLocation(current.id, current.pickup.lat, current.pickup.lng);
    });
  }

  /// Clears the finished job when the driver returns home.
  void clear() {
    emit(null);
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  @override
  Future<void> close() {
    _locationTimer?.cancel();
    return super.close();
  }
}
