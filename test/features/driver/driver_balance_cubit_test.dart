import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/driver_balance.dart';
import 'package:the_crane/features/driver/earnings/driver_balance_cubit.dart';

void main() {
  group('DriverBalanceCubit (DRV-5)', () {
    blocTest<DriverBalanceCubit, DriverBalanceState>(
      'load fetches the balance',
      build: () => DriverBalanceCubit(
        driversRepository: FakeDriversRepository(
          jobs: FakeJobsRepository(),
          actionDelay: Duration.zero,
        ),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DriverBalanceState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DriverBalanceState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.balance, 'balance', isNotNull)
            .having((s) => s.loadFailed, 'loadFailed', false),
      ],
    );

    blocTest<DriverBalanceCubit, DriverBalanceState>(
      'load surfaces a failure without crashing',
      build: () => DriverBalanceCubit(driversRepository: _FailingDrivers()),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DriverBalanceState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DriverBalanceState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loadFailed, 'loadFailed', true),
      ],
    );
  });
}

class _FailingDrivers extends FakeDriversRepository {
  _FailingDrivers() : super(jobs: FakeJobsRepository(), actionDelay: Duration.zero);

  @override
  Future<DriverBalance> balance() async {
    throw StateError('boom');
  }
}
