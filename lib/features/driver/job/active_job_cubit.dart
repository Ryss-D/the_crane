import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';

/// DRV-3 skeleton — holds the driver's active job and advances the JOB-3
/// state machine via `POST /v1/jobs/{id}/status`.
///
/// Provided at the driver shell so the job survives navigation between home
/// and the active job screen.
class ActiveJobCubit extends Cubit<Job?> {
  ActiveJobCubit({required JobsRepository jobsRepository})
      : _repo = jobsRepository,
        super(null);

  final JobsRepository _repo;
  bool _advancing = false;

  /// Set right after an accepted offer (see `OfferCubit.accept`).
  void start(Job job) => emit(job);

  /// Advances to the next driver status; no-op when the job is terminal.
  Future<void> advance() async {
    final job = state;
    final next = job?.status.nextDriverStatus;
    if (job == null || next == null || _advancing) return;
    _advancing = true;
    try {
      emit(await _repo.updateJobStatus(job.id, next));
    } catch (_) {
      // TODO(DRV-3): surface backend rejections (409/403) in the UI.
    } finally {
      _advancing = false;
    }
  }

  /// Clears the finished job when the driver returns home.
  void clear() => emit(null);
}
