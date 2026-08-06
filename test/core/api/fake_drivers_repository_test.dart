import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/truck.dart';

void main() {
  group('FakeDriversRepository.registerDriver (AUTH-5)', () {
    test('creates an unverified, offline profile with the nested truck', () async {
      final drivers = FakeDriversRepository(
        jobs: FakeJobsRepository(),
        actionDelay: Duration.zero,
      );

      final profile = await drivers.registerDriver(
        plate: 'XYZ987',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
        licenseUrl: 'https://example.com/license.png',
      );

      expect(profile.verified, isFalse);
      expect(profile.status, DriverStatus.offline);
      expect(profile.licenseUrl, 'https://example.com/license.png');
      expect(profile.truckPhotoUrl, isNull);
      expect(profile.truck, isNotNull);
      expect(profile.truck!.plate, 'XYZ987');
      expect(profile.truck!.type, TruckType.car);
      expect(profile.truck!.capacity, TruckCapacity.car);
    });

    test('flips the shared fake auth user to role driver', () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      // Sign the fake user in first, same as the real flow requires being
      // signed in before registering.
      await auth.sync(name: 'Sofía Test');

      final drivers = FakeDriversRepository(
        jobs: FakeJobsRepository(),
        auth: auth,
        actionDelay: Duration.zero,
      );
      await drivers.registerDriver(
        plate: 'XYZ987',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
      );

      final user = await auth.sync();
      expect(user.role, UserRole.driver);
    });
  });

  group('FakeDriversRepository.balance (DRV-5)', () {
    test('starts at the negative of the seeded settlement, no jobs yet',
        () async {
      final drivers = FakeDriversRepository(
        jobs: FakeJobsRepository(),
        actionDelay: Duration.zero,
      );

      final balance = await drivers.balance();

      expect(balance.recentSettlements, hasLength(1));
      expect(balance.owedCents, -balance.recentSettlements.single.amountCents);
    });

    test('accrues commission once a job the seed driver worked completes',
        () async {
      final jobs = FakeJobsRepository(
        quoteDelay: Duration.zero,
        createDelay: Duration.zero,
        actionDelay: Duration.zero,
        matchingDelay: Duration.zero,
      );
      final drivers =
          FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      final before = await drivers.balance();

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
      // matchingDelay is zero but still a Timer -- needs a real event-loop
      // turn, not just Duration.zero (see the fake-timing gotcha these
      // fakes share throughout the suite).
      await Future<void>.delayed(const Duration(milliseconds: 10));
      job = await jobs.getJob(job.id);
      expect(job.status, JobStatus.assigned);

      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
      job = await jobs.confirmDelivery(job.id);
      expect(job.status, JobStatus.completed);

      final after = await drivers.balance();
      final expectedCommission =
          (job.quotedPrice * 0.15 / 100).round() * 100;
      expect(after.owedCents, before.owedCents + expectedCommission);
    });
  });
}
