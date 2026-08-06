import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/driver/earnings/services_period_cubit.dart';

/// Drives one job all the way to `completed` through the seed driver,
/// mirroring the real driver + customer flow (advance to delivered, then
/// confirm-delivery).
Future<Job> completeAJob(FakeJobsRepository jobs) async {
  final quote = await jobs.requestQuote(
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    vehicleType: VehicleType.car,
  );
  var job = await jobs.createJob(
    quoteId: quote.quoteId,
    pickupAddress: 'Origin',
    dropoffAddress: 'Destination',
  );
  // matchingDelay is zero but still a real Timer -- needs a real
  // event-loop turn (the shared fake-timing gotcha this suite documents
  // elsewhere), not just Duration.zero.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  job = await jobs.getJob(job.id);
  while (job.status != JobStatus.delivered) {
    job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
  }
  return jobs.confirmDelivery(job.id);
}

void main() {
  FakeJobsRepository fastJobs() => FakeJobsRepository(
        quoteDelay: Duration.zero,
        createDelay: Duration.zero,
        actionDelay: Duration.zero,
        matchingDelay: Duration.zero,
      );

  group('ServicesPeriodCubit (DRV-6)', () {
    test('groups completed jobs by day with count and totals', () async {
      final jobs = fastJobs();
      final jobA = await completeAJob(jobs);
      final jobB = await completeAJob(jobs);

      final cubit = ServicesPeriodCubit(jobsRepository: jobs);
      await cubit.load();

      expect(cubit.state.loadFailed, isFalse);
      expect(cubit.state.periods, hasLength(1)); // both completed "today"
      final today = cubit.state.periods.single;
      expect(today.jobCount, 2);
      expect(today.totalFare, jobA.quotedPrice + jobB.quotedPrice);
      final expectedCommission =
          ((jobA.quotedPrice + jobB.quotedPrice) * 0.15 / 100).round() * 100;
      expect(today.totalCommission, expectedCommission);

      await cubit.close();
    });

    blocTest<ServicesPeriodCubit, ServicesPeriodState>(
      'no completed jobs yields an empty periods list, not a failure',
      build: () => ServicesPeriodCubit(jobsRepository: fastJobs()),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ServicesPeriodState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ServicesPeriodState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', false)
            .having((s) => s.periods, 'periods', isEmpty),
      ],
    );

    test('an in-progress (not completed) job is excluded from the summary',
        () async {
      final jobs = fastJobs();
      final quote = await jobs.requestQuote(
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
        vehicleType: VehicleType.car,
      );
      await jobs.createJob(
        quoteId: quote.quoteId,
        pickupAddress: 'Origin',
        dropoffAddress: 'Destination',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final cubit = ServicesPeriodCubit(jobsRepository: jobs);
      await cubit.load();

      expect(cubit.state.periods, isEmpty);
      await cubit.close();
    });
  });
}
