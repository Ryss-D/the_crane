import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_vehicles_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/saved_vehicle.dart';
import 'package:the_crane/features/customer/settings/saved_vehicles_cubit.dart';

void main() {
  group('SavedVehiclesCubit (CUS-6)', () {
    blocTest<SavedVehiclesCubit, SavedVehiclesState>(
      'load populates the seeded vehicles',
      build: () => SavedVehiclesCubit(
        vehiclesRepository: FakeVehiclesRepository(delay: Duration.zero),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SavedVehiclesState>()
            .having((s) => s.isLoading, 'isLoading', true),
        isA<SavedVehiclesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.vehicles.length, 'vehicles.length', 2),
      ],
    );

    blocTest<SavedVehiclesCubit, SavedVehiclesState>(
      'create appends the new vehicle to state',
      build: () => SavedVehiclesCubit(
        vehiclesRepository: FakeVehiclesRepository(delay: Duration.zero),
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.create(
          type: VehicleType.suv,
          plate: 'SUV001',
        );
      },
      verify: (cubit) {
        expect(cubit.state.vehicles, hasLength(3));
        expect(cubit.state.vehicles.last.plate, 'SUV001');
        expect(cubit.state.isSaving, isFalse);
      },
    );

    blocTest<SavedVehiclesCubit, SavedVehiclesState>(
      'update replaces the matching vehicle in place',
      build: () => SavedVehiclesCubit(
        vehiclesRepository: FakeVehiclesRepository(delay: Duration.zero),
      ),
      act: (cubit) async {
        await cubit.load();
        final id = cubit.state.vehicles.first.id;
        await cubit.update(id, plate: 'UPDATED');
      },
      verify: (cubit) {
        expect(cubit.state.vehicles.first.plate, 'UPDATED');
      },
    );

    blocTest<SavedVehiclesCubit, SavedVehiclesState>(
      'delete removes the vehicle from state',
      build: () => SavedVehiclesCubit(
        vehiclesRepository: FakeVehiclesRepository(delay: Duration.zero),
      ),
      act: (cubit) async {
        await cubit.load();
        final id = cubit.state.vehicles.first.id;
        await cubit.delete(id);
      },
      verify: (cubit) => expect(cubit.state.vehicles, hasLength(1)),
    );

    test('load surfaces a failure without crashing', () async {
      final cubit = SavedVehiclesCubit(vehiclesRepository: _FailingVehicles());
      await cubit.load();
      expect(cubit.state.loadFailed, isTrue);
      expect(cubit.state.isLoading, isFalse);
      await cubit.close();
    });
  });
}

class _FailingVehicles extends FakeVehiclesRepository {
  _FailingVehicles() : super(delay: Duration.zero);

  @override
  Future<List<SavedVehicle>> listVehicles() async {
    throw StateError('boom');
  }
}
