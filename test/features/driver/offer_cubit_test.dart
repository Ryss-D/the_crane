import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/driver/home/offer_cubit.dart';

void main() {
  late FakeJobsRepository jobs;
  late FakeDriversRepository drivers;

  OfferCubit buildCubit({int ttlSeconds = 3}) {
    jobs = FakeJobsRepository(actionDelay: Duration.zero);
    drivers = FakeDriversRepository(
      jobs: jobs,
      actionDelay: Duration.zero,
      offerTtlSeconds: ttlSeconds,
    );
    return OfferCubit(
      driversRepository: drivers,
      jobsRepository: jobs,
      tickInterval: const Duration(milliseconds: 10),
    );
  }

  Future<void> tick([int ms = 10]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  group('OfferCubit', () {
    test('incoming offer surfaces with the full TTL', () async {
      final cubit = buildCubit(ttlSeconds: 30);
      final offer = drivers.debugTriggerOffer();
      await tick(5);
      expect(cubit.state, isNotNull);
      expect(cubit.state!.offer.offerId, offer.offerId);
      expect(cubit.state!.remainingSeconds, 30);
      expect(cubit.state!.offer.commissionAmount, greaterThan(0));
      await cubit.close();
    });

    test('countdown reaches zero and auto-dismisses (no-response)',
        () async {
      final cubit = buildCubit(ttlSeconds: 3);
      drivers.debugTriggerOffer();
      await tick(5);
      expect(cubit.state, isNotNull);

      await tick(50); // > 3 ticks at 10ms.
      expect(cubit.state, isNull);
      await cubit.close();
    });

    test('accept returns the assigned job and clears the offer', () async {
      final cubit = buildCubit(ttlSeconds: 30);
      final offer = drivers.debugTriggerOffer();
      await tick(5);

      final job = await cubit.accept();
      expect(job, isNotNull);
      expect(job!.id, offer.job.id);
      expect(job.status, JobStatus.assigned);
      expect(job.driver, isNotNull);
      expect(cubit.state, isNull);

      // Countdown must be cancelled: state stays null.
      await tick(30);
      expect(cubit.state, isNull);
      await cubit.close();
    });

    test('reject clears the offer immediately', () async {
      final cubit = buildCubit(ttlSeconds: 30);
      drivers.debugTriggerOffer();
      await tick(5);
      expect(cubit.state, isNotNull);

      cubit.reject();
      expect(cubit.state, isNull);
      await cubit.close();
    });
  });
}
