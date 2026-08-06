import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/features/fleet/home/fleet_cubit.dart';

void main() {
  group('FleetCubit (FLT-3)', () {
    blocTest<FleetCubit, FleetState>(
      'load fetches the fleet once one exists',
      build: () => FleetCubit(
        fleetRepository:
            FakeFleetRepository(actionDelay: Duration.zero, seeded: true),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<FleetState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FleetState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', false)
            .having((s) => s.fleet?.trucks.length, 'trucks', 2),
      ],
    );

    blocTest<FleetCubit, FleetState>(
      'load surfaces a failure without crashing when there is no fleet yet',
      build: () => FleetCubit(
        fleetRepository: FakeFleetRepository(actionDelay: Duration.zero),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<FleetState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FleetState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', true),
      ],
    );

    blocTest<FleetCubit, FleetState>(
      'refresh re-fetches the fleet',
      build: () => FleetCubit(
        fleetRepository:
            FakeFleetRepository(actionDelay: Duration.zero, seeded: true),
      ),
      act: (cubit) => cubit.refresh(),
      expect: () => [
        isA<FleetState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FleetState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.fleet, 'fleet', isNotNull),
      ],
    );
  });
}
