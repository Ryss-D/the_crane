import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/driver/job/active_job_cubit.dart';

void main() {
  test('advance cycles the whole JOB-3 machine to completed', () async {
    final jobs = FakeJobsRepository(actionDelay: Duration.zero);
    final drivers =
        FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
    final cubit = ActiveJobCubit(jobsRepository: jobs);

    final offer = drivers.debugTriggerOffer();
    cubit.start(await jobs.acceptJob(offer.job.id));
    expect(cubit.state!.status, JobStatus.assigned);

    final seen = <JobStatus>[];
    while (cubit.state!.status.nextDriverStatus != null) {
      await cubit.advance();
      seen.add(cubit.state!.status);
    }
    expect(seen, [
      JobStatus.enRoutePickup,
      JobStatus.arrivedPickup,
      JobStatus.loading,
      JobStatus.inTransit,
      JobStatus.delivered,
      JobStatus.completed,
    ]);
    expect(cubit.state!.completedAt, isNotNull);

    // Terminal: advancing further is a no-op.
    await cubit.advance();
    expect(cubit.state!.status, JobStatus.completed);

    cubit.clear();
    expect(cubit.state, isNull);
    await cubit.close();
  });
}
