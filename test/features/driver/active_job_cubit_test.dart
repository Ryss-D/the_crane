import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/driver/job/active_job_cubit.dart';

void main() {
  test('advance cycles the driver-owned machine up to delivered, no further',
      () async {
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
    ]);
    expect(cubit.state!.status, JobStatus.delivered);
    expect(cubit.state!.completedAt, isNull);

    // Delivered is terminal for the driver: advancing further is a no-op —
    // only the customer's confirm-delivery (CUS-5) can complete it now.
    await cubit.advance();
    expect(cubit.state!.status, JobStatus.delivered);

    cubit.clear();
    expect(cubit.state, isNull);
    await cubit.close();
  });

  test(
    'DRV-4: the watchJob subscription reflects the customer confirming '
    'delivery live, without any driver-side action',
    () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers =
          FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      final cubit = ActiveJobCubit(jobsRepository: jobs);

      final offer = drivers.debugTriggerOffer();
      var job = await jobs.acceptJob(offer.job.id);
      cubit.start(job);
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
      // The cubit's own watchJob subscription picks these up too; give it a
      // turn before asserting.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state!.status, JobStatus.delivered);

      // Simulates the customer's `RequestDeliveryConfirmed` — an action the
      // driver side never calls directly.
      await jobs.confirmDelivery(job.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state!.status, JobStatus.completed);
      expect(cubit.state!.completedAt, isNotNull);

      cubit.clear();
      await cubit.close();
    },
  );
}
