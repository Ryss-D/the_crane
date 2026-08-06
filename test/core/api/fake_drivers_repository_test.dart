import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_auth_repository.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/driver_profile.dart';
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
}
