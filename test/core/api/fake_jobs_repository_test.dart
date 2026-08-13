import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';

/// Direct unit tests for [FakeJobsRepository] itself, targeting branches
/// that the feature-level cubit/bloc tests never happen to exercise (every
/// indirect call site always drives it down the happy path with a valid
/// quote id, a reachable next status, etc.) — see the coverage audit notes
/// in `docs/tasks/07-driver-app.md`.
///
/// Every test builds its own repository with zero/near-zero delays so
/// nothing here needs a real `Timer`-driven wait beyond the explicit
/// [FakeMatchingOutcome] cases.
FakeJobsRepository _repo({
  FakeMatchingOutcome matchingOutcome = FakeMatchingOutcome.assigned,
}) => FakeJobsRepository(
      quoteDelay: Duration.zero,
      createDelay: Duration.zero,
      actionDelay: Duration.zero,
      matchingDelay: const Duration(milliseconds: 10),
      matchingOutcome: matchingOutcome,
    );

const _pickup = LatLng(lat: 6.2442, lng: -75.5812);
const _dropoff = LatLng(lat: 6.1996, lng: -75.5726);

Future<Job> _createJob(FakeJobsRepository repo) async {
  final quote = await repo.requestQuote(
    pickup: _pickup,
    dropoff: _dropoff,
    vehicleType: VehicleType.car,
  );
  return repo.createJob(
    quoteId: quote.quoteId,
    vehicleType: VehicleType.car,
    pickup: _pickup,
    pickupAddress: 'Cra. 43A #5-15, El Poblado',
    dropoff: _dropoff,
    dropoffAddress: 'C.C. Mayorca, Sabaneta',
  );
}

void main() {
  group('createJob', () {
    test('throws StateError for an unknown or expired quote id', () async {
      final repo = _repo();
      expect(
        () => repo.createJob(
          quoteId: 'no-such-quote',
          vehicleType: VehicleType.car,
          pickup: _pickup,
          pickupAddress: 'A',
          dropoff: _dropoff,
          dropoffAddress: 'B',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getJob / acceptJob', () {
    test('getJob throws StateError for an unknown id', () async {
      final repo = _repo();
      expect(() => repo.getJob('no-such-job'), throwsA(isA<StateError>()));
    });

    test('acceptJob throws StateError for an unknown id', () async {
      final repo = _repo();
      expect(() => repo.acceptJob('no-such-job'), throwsA(isA<StateError>()));
    });
  });

  group('watchJob', () {
    test('does not emit an initial snapshot for a job that does not exist',
        () async {
      final repo = _repo();
      final events = <Job>[];
      final sub = repo.watchJob('no-such-job').listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  group('cancelJob', () {
    test('throws StateError for an unknown id', () async {
      final repo = _repo();
      expect(() => repo.cancelJob('no-such-job'), throwsA(isA<StateError>()));
    });

    test(
      'a customer cancel (asDriver: false) on a job past the grace period '
      'is rejected with StateError, mirroring the backend 409',
      () async {
        final repo = _repo();
        var job = await _createJob(repo);
        job = await repo.acceptJob(job.id);
        // en_route_pickup is outside `_customerCancellable`
        // (requested/matching/assigned).
        job = await repo.updateJobStatus(job.id, job.status.nextDriverStatus!);
        expect(job.status, JobStatus.enRoutePickup);

        expect(
          () => repo.cancelJob(job.id),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'a customer cancel while still matching succeeds and marks the job '
      'cancelled with a customer reason',
      () async {
        final repo = _repo();
        final job = await _createJob(repo);
        expect(job.status, JobStatus.matching);

        final cancelled = await repo.cancelJob(job.id);

        expect(cancelled.status, JobStatus.cancelled);
        expect(cancelled.cancelReason, 'customer');
        expect(cancelled.cancelledAt, isNotNull);
      },
    );
  });

  group('updateJobStatus', () {
    test(
      'rejects a target status that does not follow the current one, '
      'mirroring the backend 409 (JobTransitionError)',
      () async {
        final repo = _repo();
        var job = await _createJob(repo);
        job = await repo.acceptJob(job.id); // status: assigned
        expect(job.status, JobStatus.assigned);

        // Skips straight to `delivered`, well past the actual next status
        // (`en_route_pickup`).
        expect(
          () => repo.updateJobStatus(job.id, JobStatus.delivered),
          throwsA(isA<JobStatusRejectedException>()),
        );
      },
    );

    test('throws StateError for an unknown id', () async {
      final repo = _repo();
      expect(
        () => repo.updateJobStatus('no-such-job', JobStatus.enRoutePickup),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('confirmDelivery', () {
    test('throws StateError when the job is not yet delivered', () async {
      final repo = _repo();
      final job = await _createJob(repo); // status: matching

      expect(
        () => repo.confirmDelivery(job.id),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError for an unknown id', () async {
      final repo = _repo();
      expect(
        () => repo.confirmDelivery('no-such-job'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('submitRating / getRatings', () {
    test('getRatings on a job with none yet returns an empty list', () async {
      final repo = _repo();
      final job = await _createJob(repo);

      expect(await repo.getRatings(job.id), isEmpty);
    });

    test('a whitespace-only comment is stored as null, not blank text', () async {
      final repo = _repo();
      final job = await _createJob(repo);

      await repo.submitRating(job.id, stars: 5, comment: '   ');

      final ratings = await repo.getRatings(job.id);
      expect(ratings, hasLength(1));
      expect(ratings.single.comment, isNull);
      expect(ratings.single.stars, 5);
    });

    test('a real comment is trimmed and both sides can rate independently',
        () async {
      final repo = _repo();
      final job = await _createJob(repo);

      await repo.submitRating(job.id, stars: 4, comment: '  Great service!  ');
      await repo.submitRating(job.id, stars: 2, comment: null);

      final ratings = await repo.getRatings(job.id);
      expect(ratings, hasLength(2));
      expect(ratings.first.comment, 'Great service!');
      expect(ratings.first.jobId, job.id);
      expect(ratings.first.fromUserId, job.customerId);
      expect(ratings.last.comment, isNull);
    });

    test('submitRating throws StateError for an unknown job', () async {
      final repo = _repo();
      expect(
        () => repo.submitRating('no-such-job', stars: 5),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('listHistory pagination', () {
    test(
      'offset beyond the total returns an empty page while still '
      'reporting the true total',
      () async {
        final repo = _repo();
        await _createJob(repo);
        await _createJob(repo);

        final page = await repo.listHistory(
          role: JobHistoryRole.customer,
          limit: 20,
          offset: 50,
        );

        expect(page.items, isEmpty);
        expect(page.total, 2);
        expect(page.limit, 20);
        expect(page.offset, 50);
      },
    );

    test('limit truncates the page while total reflects every match',
        () async {
        final repo = _repo();
        await _createJob(repo);
        await _createJob(repo);
        await _createJob(repo);

        final page = await repo.listHistory(
          role: JobHistoryRole.customer,
          limit: 1,
          offset: 1,
        );

        expect(page.items, hasLength(1));
        expect(page.total, 3);
      },
    );

    test('role: driver only returns jobs assigned to the current '
        'driverOverride', () async {
      final repo = _repo();
      final untouched = await _createJob(repo);
      final assigned = await _createJob(repo);
      await repo.acceptJob(assigned.id);

      final page = await repo.listHistory(role: JobHistoryRole.driver);

      expect(page.items.map((j) => j.id), [assigned.id]);
      expect(page.items.any((j) => j.id == untouched.id), isFalse);
    });
  });
}
