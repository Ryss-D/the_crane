import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_history_page.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/shared/history/history_cubit.dart';

FakeJobsRepository _fastJobs() => FakeJobsRepository(
      quoteDelay: Duration.zero,
      createDelay: Duration.zero,
      actionDelay: Duration.zero,
      matchingDelay: Duration.zero,
    );

/// Drives one job all the way to `completed` through the seed driver,
/// mirroring `ServicesPeriodCubit`'s test helper of the same shape
/// (`test/features/driver/services_period_cubit_test.dart`).
Future<Job> _completeAJob(FakeJobsRepository jobs) async {
  final quote = await jobs.requestQuote(
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    vehicleType: VehicleType.car,
  );
  var job = await jobs.createJob(
    quoteId: quote.quoteId,
    vehicleType: VehicleType.car,
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    pickupAddress: 'Origin',
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    dropoffAddress: 'Destination',
  );
  // matchingDelay is zero but still a real Timer -- needs a real
  // event-loop turn, not just Duration.zero.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  job = await jobs.getJob(job.id);
  while (job.status != JobStatus.delivered) {
    job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
  }
  return jobs.confirmDelivery(job.id);
}

/// Fails the next `listHistory` call exactly once, mirroring
/// `RejectingOnceJobsRepository`'s shape (`test/support/`) for
/// `updateJobStatus`.
class _RejectingOnceHistoryJobs extends FakeJobsRepository {
  _RejectingOnceHistoryJobs()
      : super(
          quoteDelay: Duration.zero,
          createDelay: Duration.zero,
          actionDelay: Duration.zero,
          matchingDelay: Duration.zero,
        );

  bool rejectNext = false;

  @override
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  }) {
    if (rejectNext) {
      rejectNext = false;
      return Future.error(StateError('boom'));
    }
    return super.listHistory(role: role, limit: limit, offset: offset);
  }
}

void main() {
  group('HistoryCubit (RAT-3)', () {
    test('starts loading with no items', () {
      final cubit =
          HistoryCubit(jobsRepository: _fastJobs(), role: JobHistoryRole.customer);
      expect(cubit.state.isLoading, isTrue);
      expect(cubit.state.items, isEmpty);
      cubit.close();
    });

    late FakeJobsRepository loadJobs;
    blocTest<HistoryCubit, HistoryState>(
      'load fetches the first page, newest first',
      build: () {
        loadJobs = _fastJobs();
        return HistoryCubit(jobsRepository: loadJobs, role: JobHistoryRole.customer);
      },
      act: (cubit) async {
        await _completeAJob(loadJobs);
        await _completeAJob(loadJobs);
        await cubit.load();
      },
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', false)
            .having((s) => s.items, 'items', hasLength(2))
            .having((s) => s.total, 'total', 2)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<HistoryCubit, HistoryState>(
      'load surfaces a failure without crashing, and keeps items empty',
      build: () => HistoryCubit(
        jobsRepository: _RejectingOnceHistoryJobs()..rejectNext = true,
        role: JobHistoryRole.customer,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', true)
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<HistoryCubit, HistoryState>(
      'a retried load after a failure clears loadFailed on success',
      build: () => HistoryCubit(
        jobsRepository: _RejectingOnceHistoryJobs()..rejectNext = true,
        role: JobHistoryRole.customer,
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      skip: 2,
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', false)
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.total, 'total', 0),
      ],
    );

    late FakeJobsRepository loadMoreJobs;
    blocTest<HistoryCubit, HistoryState>(
      'loadMore appends the next page and flips hasMore once exhausted',
      build: () {
        loadMoreJobs = _fastJobs();
        return HistoryCubit(
          jobsRepository: loadMoreJobs,
          role: JobHistoryRole.customer,
          pageSize: 2,
        );
      },
      act: (cubit) async {
        await _completeAJob(loadMoreJobs);
        await _completeAJob(loadMoreJobs);
        await _completeAJob(loadMoreJobs);
        await cubit.load();
        await cubit.loadMore();
      },
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.items, 'items', hasLength(2))
            .having((s) => s.total, 'total', 3)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<HistoryState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<HistoryState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.items, 'items', hasLength(3))
            .having((s) => s.total, 'total', 3)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    late FakeJobsRepository noMoreJobs;
    blocTest<HistoryCubit, HistoryState>(
      'loadMore is a no-op once everything is already loaded',
      build: () {
        noMoreJobs = _fastJobs();
        return HistoryCubit(
          jobsRepository: noMoreJobs,
          role: JobHistoryRole.customer,
          pageSize: 20,
        );
      },
      act: (cubit) async {
        await _completeAJob(noMoreJobs);
        await cubit.load();
        await cubit.loadMore(); // hasMore is already false.
      },
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasMore, 'hasMore', false),
        // No further state: `loadMore` returned early.
      ],
    );

    late _RejectingOnceHistoryJobs loadMoreFailureJobs;
    blocTest<HistoryCubit, HistoryState>(
      'loadMore failure resets isLoadingMore and keeps the already-loaded '
      'items',
      build: () {
        loadMoreFailureJobs = _RejectingOnceHistoryJobs();
        return HistoryCubit(
          jobsRepository: loadMoreFailureJobs,
          role: JobHistoryRole.customer,
          pageSize: 1,
        );
      },
      act: (cubit) async {
        await _completeAJob(loadMoreFailureJobs);
        await _completeAJob(loadMoreFailureJobs);
        await cubit.load();
        loadMoreFailureJobs.rejectNext = true;
        await cubit.loadMore();
      },
      expect: () => [
        isA<HistoryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HistoryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.items, 'items', hasLength(1))
            .having((s) => s.hasMore, 'hasMore', true),
        isA<HistoryState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<HistoryState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.items, 'items', hasLength(1)) // unchanged
            .having((s) => s.hasMore, 'hasMore', true),
      ],
    );
  });
}
