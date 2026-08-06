import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';

/// DRV-3 test double: rejects the *next* `updateJobStatus` call exactly
/// like the real backend would (409 `JobTransitionError`/403 —
/// [JobStatusRejectedException]), then falls back to the normal fake
/// behavior. Lets tests trigger `ActiveJobCubit`'s rejection-surfacing path
/// without contriving an actually-illegal transition.
class RejectingOnceJobsRepository extends FakeJobsRepository {
  RejectingOnceJobsRepository({super.actionDelay});

  bool rejectNext = false;

  @override
  Future<Job> updateJobStatus(String id, JobStatus status) {
    if (rejectNext) {
      rejectNext = false;
      return Future.error(
        JobStatusRejectedException('Drivers cannot set status ${status.wire}'),
      );
    }
    return super.updateJobStatus(id, status);
  }
}
