import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/driver/job/active_job_cubit.dart';

import '../../support/rejecting_jobs_repository.dart';

void main() {
  test('advance cycles the driver-owned machine up to delivered, no further',
      () async {
    final jobs = FakeJobsRepository(actionDelay: Duration.zero);
    final drivers =
        FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
    final cubit = ActiveJobCubit(jobsRepository: jobs);

    final offer = drivers.debugTriggerOffer();
    cubit.start(await jobs.acceptJob(offer.job.id));
    expect(cubit.state.job!.status, JobStatus.assigned);

    final seen = <JobStatus>[];
    while (cubit.state.job!.status.nextDriverStatus != null) {
      await cubit.advance();
      seen.add(cubit.state.job!.status);
    }
    expect(seen, [
      JobStatus.enRoutePickup,
      JobStatus.arrivedPickup,
      JobStatus.loading,
      JobStatus.inTransit,
      JobStatus.delivered,
    ]);
    expect(cubit.state.job!.status, JobStatus.delivered);
    expect(cubit.state.job!.completedAt, isNull);

    // Delivered is terminal for the driver: advancing further is a no-op —
    // only the customer's confirm-delivery (CUS-5) can complete it now.
    await cubit.advance();
    expect(cubit.state.job!.status, JobStatus.delivered);

    cubit.clear();
    expect(cubit.state.job, isNull);
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
      expect(cubit.state.job!.status, JobStatus.delivered);

      // Simulates the customer's `RequestDeliveryConfirmed` — an action the
      // driver side never calls directly.
      await jobs.confirmDelivery(job.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.job!.status, JobStatus.completed);
      expect(cubit.state.job!.completedAt, isNotNull);

      cubit.clear();
      await cubit.close();
    },
  );

  test(
    'DRV-3: a rejected advance() surfaces the backend message and leaves '
    'the job untouched; a later success clears it',
    () async {
      final jobs = RejectingOnceJobsRepository(actionDelay: Duration.zero);
      final drivers =
          FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      final cubit = ActiveJobCubit(jobsRepository: jobs);

      final offer = drivers.debugTriggerOffer();
      cubit.start(await jobs.acceptJob(offer.job.id));
      expect(cubit.state.errorMessage, isNull);

      jobs.rejectNext = true;
      await cubit.advance();

      expect(cubit.state.errorMessage, 'Drivers cannot set status en_route_pickup');
      expect(cubit.state.job!.status, JobStatus.assigned);

      await cubit.advance();
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.job!.status, JobStatus.enRoutePickup);

      cubit.clear();
      await cubit.close();
    },
  );

  test(
    'DRV-3: cancel() releases the job back to matching while still '
    'cancellable, and clears the local state',
    () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers =
          FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      final cubit = ActiveJobCubit(jobsRepository: jobs);

      final offer = drivers.debugTriggerOffer();
      cubit.start(await jobs.acceptJob(offer.job.id));
      expect(cubit.state.job!.status, JobStatus.assigned);

      await cubit.cancel();

      expect(cubit.state.job, isNull);
      final job = await jobs.getJob(offer.job.id);
      expect(job.status, JobStatus.matching);
      expect(job.driverId, isNull);

      await cubit.close();
    },
  );

  test(
    'DRV-3: a rejected cancel() (past arrived_pickup) surfaces the '
    'backend message and leaves the job untouched',
    () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers =
          FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      final cubit = ActiveJobCubit(jobsRepository: jobs);

      final offer = drivers.debugTriggerOffer();
      cubit.start(await jobs.acceptJob(offer.job.id));
      await cubit.advance(); // -> en_route_pickup
      await cubit.advance(); // -> arrived_pickup
      await cubit.advance(); // -> loading (no longer cancellable)
      expect(cubit.state.job!.status, JobStatus.loading);

      await cubit.cancel();

      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.job!.status, JobStatus.loading);

      cubit.clear();
      await cubit.close();
    },
  );
}
