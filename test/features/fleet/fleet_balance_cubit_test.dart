import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/features/fleet/balance/fleet_balance_cubit.dart';

void main() {
  group('FleetBalanceCubit (FLT-5)', () {
    blocTest<FleetBalanceCubit, FleetBalanceState>(
      'load fetches the consolidated balance and its members',
      build: () => FleetBalanceCubit(
        fleetRepository:
            FakeFleetRepository(actionDelay: Duration.zero, seeded: true),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<FleetBalanceState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FleetBalanceState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', false)
            .having((s) => s.balance?.members.length, 'members', 2)
            // The fake's two seeded members owe 45000 + 12000.
            .having((s) => s.balance?.owedBalance, 'owedBalance', 57000),
      ],
    );

    blocTest<FleetBalanceCubit, FleetBalanceState>(
      'load surfaces a failure without crashing when there is no fleet yet',
      build: () => FleetBalanceCubit(
        fleetRepository: FakeFleetRepository(actionDelay: Duration.zero),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<FleetBalanceState>().having((s) => s.isLoading, 'isLoading', true),
        isA<FleetBalanceState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', true),
      ],
    );
  });
}
