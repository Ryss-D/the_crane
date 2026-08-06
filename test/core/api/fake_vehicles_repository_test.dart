import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_vehicles_repository.dart';
import 'package:the_crane/core/models/job.dart';

void main() {
  group('FakeVehiclesRepository (CUS-6)', () {
    test('seeds a couple of vehicles', () async {
      final repo = FakeVehiclesRepository(delay: Duration.zero);
      final vehicles = await repo.listVehicles();
      expect(vehicles, hasLength(2));
    });

    test('createVehicle appends and returns the new vehicle', () async {
      final repo = FakeVehiclesRepository(delay: Duration.zero);
      final created = await repo.createVehicle(
        type: VehicleType.suv,
        make: 'Toyota',
        model: 'Fortuner',
        plate: 'SUV001',
      );
      expect(created.plate, 'SUV001');
      final vehicles = await repo.listVehicles();
      expect(vehicles, hasLength(3));
      expect(vehicles.last, created);
    });

    test('updateVehicle patches only the given fields', () async {
      final repo = FakeVehiclesRepository(delay: Duration.zero);
      final vehicles = await repo.listVehicles();
      final target = vehicles.first;

      final updated = await repo.updateVehicle(target.id, plate: 'NEWPLT');

      expect(updated.plate, 'NEWPLT');
      expect(updated.type, target.type);
      expect(updated.make, target.make);
      expect(updated.model, target.model);
    });

    test('updateVehicle on an unknown id throws', () async {
      final repo = FakeVehiclesRepository(delay: Duration.zero);
      expect(
        () => repo.updateVehicle('unknown-id', plate: 'X'),
        throwsStateError,
      );
    });

    test('deleteVehicle removes it from the list', () async {
      final repo = FakeVehiclesRepository(delay: Duration.zero);
      final vehicles = await repo.listVehicles();
      await repo.deleteVehicle(vehicles.first.id);
      final remaining = await repo.listVehicles();
      expect(remaining, hasLength(1));
      expect(remaining.any((v) => v.id == vehicles.first.id), isFalse);
    });
  });
}
