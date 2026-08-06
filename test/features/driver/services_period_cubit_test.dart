import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_history_page.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/driver/earnings/services_period_cubit.dart';

/// DRV-6 period-filter test double: hands back a fixed set of completed
/// jobs with controllable `completedAt` timestamps, so filter behavior
/// (today/week/month/custom) can be tested deterministically — the real
/// `FakeJobsRepository` always completes jobs at `DateTime.now()`, with no
/// way to backdate one through its public API. Only `listHistory` (the
/// only method `ServicesPeriodCubit` calls) is implemented.
class SeededHistoryJobsRepository implements JobsRepository {
  SeededHistoryJobsRepository(this._jobs);

  final List<Job> _jobs;

  @override
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  }) async {
    return JobHistoryPage(
      items: _jobs,
      total: _jobs.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed by these tests');
}

int _seq = 0;

Job _completedJob({required DateTime completedAt, int price = 100000}) {
  final id = 'job-${++_seq}';
  return Job(
    id: id,
    customerId: 'cus-001',
    status: JobStatus.completed,
    vehicleType: VehicleType.car,
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    pickupAddress: 'Origin',
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    dropoffAddress: 'Destination',
    distanceKm: 5,
    quotedPrice: price,
    requestedAt: completedAt,
    completedAt: completedAt,
  );
}

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

  // The "remembered filter/range" static state (see the cubit's own doc
  // comment) otherwise leaks between tests in this file.
  setUp(ServicesPeriodCubit.resetRememberedFilterForTest);

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

  group('ServicesPeriodCubit period selector (DRV-6)', () {
    late DateTime now;
    late SeededHistoryJobsRepository repo;

    setUp(() {
      now = DateTime.now();
      repo = SeededHistoryJobsRepository([
        _completedJob(completedAt: now, price: 100000), // today
        _completedJob(completedAt: now.subtract(const Duration(days: 3)), price: 50000), // this week, not today
        _completedJob(completedAt: now.subtract(const Duration(days: 20)), price: 70000), // outside the rolling week
        _completedJob(completedAt: now.subtract(const Duration(days: 400)), price: 90000), // over a year ago
      ]);
    });

    test('defaults to today, matching the one job completed today',
        () async {
      final cubit = ServicesPeriodCubit(jobsRepository: repo);
      await cubit.load();

      expect(cubit.state.filter, ServicesPeriodFilter.today);
      expect(cubit.state.totalJobCount, 1);
      expect(cubit.state.totalFare, 100000);

      await cubit.close();
    });

    test('week includes today and the 3-days-ago job, not older ones',
        () async {
      final cubit = ServicesPeriodCubit(jobsRepository: repo);
      await cubit.load();

      cubit.setFilter(ServicesPeriodFilter.week);

      expect(cubit.state.totalJobCount, 2);
      expect(cubit.state.totalFare, 150000);

      await cubit.close();
    });

    test('custom range picks exactly the jobs inside it, and remembers '
        'the range for the next cubit instance', () async {
      final cubit = ServicesPeriodCubit(jobsRepository: repo);
      await cubit.load();

      final start = now.subtract(const Duration(days: 25));
      final end = now.subtract(const Duration(days: 10));
      cubit.setCustomRange(start, end);

      expect(cubit.state.filter, ServicesPeriodFilter.custom);
      expect(cubit.state.totalJobCount, 1); // only the 20-days-ago job
      expect(cubit.state.totalFare, 70000);
      await cubit.close();

      // A freshly-created cubit (e.g. reopening the screen) sees the same
      // remembered filter and range, not the today default.
      final reopened = ServicesPeriodCubit(jobsRepository: repo);
      expect(reopened.state.filter, ServicesPeriodFilter.custom);
      expect(reopened.state.customStart, isNotNull);
      expect(reopened.state.customEnd, isNotNull);
      await reopened.close();
    });

    test('maxDayFare backs the bar-list widths', () async {
      final cubit = ServicesPeriodCubit(jobsRepository: repo);
      await cubit.load();
      cubit.setFilter(ServicesPeriodFilter.week);

      expect(cubit.state.maxDayFare, 100000); // the larger of the two days
      await cubit.close();
    });
  });
}
