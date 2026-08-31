import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/drivers_repository.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/driver_balance.dart';
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

    test('redeems a fleet invite instead of creating a new truck (FLT-4)',
        () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      await auth.sync(name: 'Sofía Test');
      final fleet = FakeFleetRepository(auth: auth, actionDelay: Duration.zero);
      await fleet.createFleet(name: 'Grúas del Valle');
      final invite = await fleet.createInvite(
        // Matches FakeAuthRepository's fixed seed phone.
        phone: '+573000000000',
        plate: 'INV001',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
      );

      final drivers = FakeDriversRepository(
        jobs: FakeJobsRepository(),
        auth: auth,
        fleet: fleet,
        actionDelay: Duration.zero,
      );
      final profile = await drivers.registerDriver(inviteToken: invite.inviteToken);

      expect(profile.truck!.plate, 'INV001');
      expect(await fleet.listInvites(), isEmpty);
      final user = await auth.sync();
      expect(user.role, UserRole.driver);
    });

    test('throws when the invite phone does not match the caller',
        () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      await auth.sync(name: 'Sofía Test');
      final fleet = FakeFleetRepository(auth: auth, actionDelay: Duration.zero);
      await fleet.createFleet(name: 'Grúas del Valle');
      final invite = await fleet.createInvite(
        phone: '+573009998877',
        plate: 'INV001',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
      );

      final drivers = FakeDriversRepository(
        jobs: FakeJobsRepository(),
        auth: auth,
        fleet: fleet,
        actionDelay: Duration.zero,
      );

      expect(
        () => drivers.registerDriver(inviteToken: invite.inviteToken),
        throwsStateError,
      );
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
        vehicleType: VehicleType.car,
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        pickupAddress: 'Origin',
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
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

  group('FakeDriversRepository.settleBalance (PAY-3)', () {
    /// Seed data alone owes nothing (negative of the seeded settlement) --
    /// every test in this group needs a real positive balance first. The
    /// seed settlement (180000) starts the balance well negative, and one
    /// job's commission alone doesn't clear it -- completes jobs one at a
    /// time until it does (capped, so a real regression fails fast instead
    /// of hanging).
    Future<(FakeDriversRepository, int owedCents)> driversWithOwedBalance() async {
      final jobs = FakeJobsRepository(
        quoteDelay: Duration.zero,
        createDelay: Duration.zero,
        actionDelay: Duration.zero,
        matchingDelay: Duration.zero,
      );
      final drivers = FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);

      Future<void> completeOneJob() async {
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
        // matchingDelay is zero but still a Timer -- needs a real
        // event-loop turn, and `job` here is still the `matching`-status
        // snapshot `createJob` returned, not the `assigned` one the watch
        // stream produces after -- re-fetch before advancing it (see the
        // fake-timing gotcha this suite's other tests flag the same way).
        await Future<void>.delayed(const Duration(milliseconds: 10));
        job = await jobs.getJob(job.id);
        while (job.status != JobStatus.delivered) {
          job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
        }
        await jobs.confirmDelivery(job.id);
      }

      var owed = (await drivers.balance()).owedCents;
      var guard = 0;
      while (owed <= 0 && guard < 20) {
        await completeOneJob();
        owed = (await drivers.balance()).owedCents;
        guard++;
      }
      return (drivers, owed);
    }

    test('nequi has no redirect url, pse/card do', () async {
      final (drivers, owed) = await driversWithOwedBalance();
      expect(owed, greaterThan(0));

      final nequi = await drivers.settleBalance(amountCop: owed);
      expect(nequi.asyncPaymentUrl, isNull);

      final pse = await drivers.settleBalance(
        amountCop: owed,
        method: SettlementPaymentMethod.pse,
      );
      expect(pse.asyncPaymentUrl, isNotNull);
    });

    test('never moves the balance itself -- only a real webhook does',
        () async {
      final (drivers, owed) = await driversWithOwedBalance();

      await drivers.settleBalance(amountCop: owed);

      expect((await drivers.balance()).owedCents, owed);
    });

    test('rejects nothing owed', () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers = FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
      // Seed data alone owes a negative amount (a past settlement with no
      // completed jobs since) -- <= 0 either way.
      expect(
        () => drivers.settleBalance(amountCop: 1000),
        throwsA(isA<SettlementRejectedException>()),
      );
    });

    test('rejects a non-positive amount', () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers = FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);

      expect(
        () => drivers.settleBalance(amountCop: 0),
        throwsA(isA<SettlementRejectedException>()),
      );
    });

    test('rejects an amount exceeding the owed balance', () async {
      final (drivers, owed) = await driversWithOwedBalance();

      expect(
        () => drivers.settleBalance(amountCop: owed + 100000),
        throwsA(isA<SettlementRejectedException>()),
      );
    });

    test('rejectNextSettleAsUnavailable simulates the no-key 503 once',
        () async {
      final jobs = FakeJobsRepository(actionDelay: Duration.zero);
      final drivers = FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero)
        ..rejectNextSettleAsUnavailable = true;

      expect(
        () => drivers.settleBalance(amountCop: 1000),
        throwsA(isA<SettlementRejectedException>()),
      );
    });
  });
}
