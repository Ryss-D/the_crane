import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/api/fleet_repository.dart';
import 'package:the_crane/core/models/app_user.dart';

void main() {
  group('FakeFleetRepository.createFleet (FLT-1)', () {
    test('creates a fleet seeded with two trucks', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);

      final fleet = await fleets.createFleet(name: 'Grúas del Valle');

      expect(fleet.name, 'Grúas del Valle');
      expect(fleet.trucks, hasLength(2));
    });

    test('throws on a second createFleet call', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');

      expect(
        () => fleets.createFleet(name: 'Otra flota'),
        throwsStateError,
      );
    });

    test('flips the shared fake auth user to role fleetOwner', () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      await auth.sync(name: 'Sofía Test');

      final fleets = FakeFleetRepository(auth: auth, actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');

      final user = await auth.sync();
      expect(user.role, UserRole.fleetOwner);
    });
  });

  group('FakeFleetRepository.getMyFleet', () {
    test('throws before a fleet exists', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      expect(fleets.getMyFleet(), throwsStateError);
    });

    test('a seeded repository already has a fleet', () async {
      final fleets =
          FakeFleetRepository(actionDelay: Duration.zero, seeded: true);
      final fleet = await fleets.getMyFleet();
      expect(fleet.trucks, hasLength(2));
    });
  });

  group('FakeFleetRepository.findTruckByPlate (FLT-4)', () {
    test('finds an unclaimed truck', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      final truck = await fleets.findTruckByPlate('NEW001');
      expect(truck.fleetId, isNull);
    });

    test('finds a truck already claimed by another fleet', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      final truck = await fleets.findTruckByPlate('OTR001');
      expect(truck.fleetId, isNotNull);
    });

    test('throws TruckNotFoundException for an unknown plate', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      expect(
        fleets.findTruckByPlate('NOPE00'),
        throwsA(isA<TruckNotFoundException>()),
      );
    });
  });

  group('FakeFleetRepository.attachTruck/detachTruck (FLT-4)', () {
    test('attaches an unclaimed truck to the caller fleet', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');
      final truck = await fleets.findTruckByPlate('NEW001');

      final fleet = await fleets.attachTruck(truck.id);

      expect(fleet.trucks, hasLength(3));
      expect(fleet.trucks.any((t) => t.plate == 'NEW001'), isTrue);
    });

    test('throws attaching a truck already claimed by another fleet',
        () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');
      final truck = await fleets.findTruckByPlate('OTR001');

      expect(() => fleets.attachTruck(truck.id), throwsStateError);
    });

    test('detaches a truck back to unclaimed', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      final fleet = await fleets.createFleet(name: 'Grúas del Valle');
      final truckId = fleet.trucks.first.id;

      final updated = await fleets.detachTruck(truckId);

      expect(updated.trucks.any((t) => t.id == truckId), isFalse);
      final truck = await fleets.findTruckByPlate(fleet.trucks.first.plate);
      expect(truck.fleetId, isNull);
    });

    test('throws detaching a truck that is not a member', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');

      expect(() => fleets.detachTruck('unknown-id'), throwsStateError);
    });
  });

  group('FakeFleetRepository.getBalance (FLT-2/FLT-5)', () {
    test('returns the consolidated balance across seeded members', () async {
      final fleets = FakeFleetRepository(actionDelay: Duration.zero);
      await fleets.createFleet(name: 'Grúas del Valle');

      final balance = await fleets.getBalance();

      expect(balance.members, hasLength(2));
      expect(
        balance.owedBalance,
        balance.members.fold<int>(0, (sum, m) => sum + m.owedBalance),
      );
    });
  });
}
