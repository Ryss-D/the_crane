import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/features/driver/home/driver_home_cubit.dart';

FakeDriversRepository instantFakeDrivers({bool verified = true}) {
  return FakeDriversRepository(
    jobs: FakeJobsRepository(),
    actionDelay: Duration.zero,
    verified: verified,
  );
}

void main() {
  group('DriverHomeCubit', () {
    blocTest<DriverHomeCubit, DriverHomeState>(
      'toggling from offline goes available (with updating state in between)',
      build: () =>
          DriverHomeCubit(driversRepository: instantFakeDrivers()),
      act: (cubit) => cubit.toggleAvailability(),
      expect: () => [
        const DriverHomeState(isUpdating: true),
        isA<DriverHomeState>()
            .having((s) => s.status, 'status', DriverStatus.available)
            .having((s) => s.isUpdating, 'isUpdating', false)
            .having((s) => s.profile, 'profile', isNotNull),
      ],
    );

    blocTest<DriverHomeCubit, DriverHomeState>(
      'toggling twice returns to offline',
      build: () =>
          DriverHomeCubit(driversRepository: instantFakeDrivers()),
      act: (cubit) async {
        await cubit.toggleAvailability();
        await cubit.toggleAvailability();
      },
      verify: (cubit) {
        expect(cubit.state.status, DriverStatus.offline);
        expect(cubit.state.isUpdating, isFalse);
      },
    );

    blocTest<DriverHomeCubit, DriverHomeState>(
      'unverified profile surfaces the blocked state',
      build: () => DriverHomeCubit(
        driversRepository: instantFakeDrivers(verified: false),
      ),
      act: (cubit) => cubit.toggleAvailability(),
      verify: (cubit) => expect(cubit.state.isBlocked, isTrue),
    );
  });
}
