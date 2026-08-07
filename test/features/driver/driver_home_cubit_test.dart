import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/location/location_source.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/notifications/notification_permission_requester.dart';
import 'package:the_crane/features/driver/home/driver_home_cubit.dart';

FakeDriversRepository instantFakeDrivers({
  bool verified = true,
  DriverStatus status = DriverStatus.offline,
}) {
  return FakeDriversRepository(
    jobs: FakeJobsRepository(),
    actionDelay: Duration.zero,
    verified: verified,
    status: status,
  );
}

/// A granted-permission location source with a fixed one-shot fix, for
/// asserting `DriverHomeCubit` actually sends `lat`/`lng` when going
/// available — the real backend 422s the real endpoint without them.
class _FixedLocationSource implements LocationSource {
  const _FixedLocationSource(this.fix, {this.permissionGranted = true});

  final LatLng fix;
  final bool permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Stream<LatLng> watchPosition() => Stream.value(fix);

  @override
  Future<LatLng> getCurrentPosition() async => fix;
}

/// TRK-3: records how many times permission was requested, so tests can
/// assert `DriverHomeCubit` actually asks when going available without
/// needing real `firebase_messaging`/`flutter_local_notifications` calls.
class _RecordingNotificationPermissionRequester
    implements NotificationPermissionRequester {
  int requestCount = 0;

  @override
  Future<void> requestPermission() async {
    requestCount++;
  }
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
      verify: (cubit) {
        expect(cubit.state.isBlocked, isTrue);
        expect(cubit.state.blockReason, DriverBlockReason.unverified);
      },
    );

    blocTest<DriverHomeCubit, DriverHomeState>(
      'an admin-blocked profile surfaces its own distinct reason '
      '(not the unverified one)',
      build: () => DriverHomeCubit(
        driversRepository: instantFakeDrivers(status: DriverStatus.blocked),
      ),
      act: (cubit) => cubit.toggleAvailability(),
      verify: (cubit) {
        expect(cubit.state.isBlocked, isTrue);
        expect(cubit.state.blockReason, DriverBlockReason.adminBlocked);
      },
    );

    blocTest<DriverHomeCubit, DriverHomeState>(
      'DRV-1: a balance-cap rejection on going available surfaces its own '
      'distinct reason, captured from the DioException detail',
      build: () {
        final drivers = instantFakeDrivers()
          ..rejectNextAvailableWithBalanceCap = true;
        return DriverHomeCubit(driversRepository: drivers);
      },
      act: (cubit) => cubit.toggleAvailability(),
      verify: (cubit) {
        expect(cubit.state.isBlocked, isTrue);
        expect(cubit.state.blockReason, DriverBlockReason.balanceCap);
        // The rejected attempt didn't actually flip status.
        expect(cubit.state.status, DriverStatus.offline);
      },
    );

    blocTest<DriverHomeCubit, DriverHomeState>(
      'DRV-1: a later successful toggle clears the balance-cap reason',
      build: () {
        final drivers = instantFakeDrivers()
          ..rejectNextAvailableWithBalanceCap = true;
        return DriverHomeCubit(driversRepository: drivers);
      },
      act: (cubit) async {
        await cubit.toggleAvailability(); // rejected
        await cubit.toggleAvailability(); // succeeds this time
      },
      verify: (cubit) {
        expect(cubit.state.isBlocked, isFalse);
        expect(cubit.state.blockReason, DriverBlockReason.none);
        expect(cubit.state.status, DriverStatus.available);
      },
    );

    test(
      'going available sends a real fix, so the real backend '
      "won't 422 for missing lat/lng",
      () async {
        final drivers = instantFakeDrivers();
        final cubit = DriverHomeCubit(
          driversRepository: drivers,
          locationSource: const _FixedLocationSource(
            LatLng(lat: 6.2442, lng: -75.5812),
          ),
        );

        await cubit.toggleAvailability();

        expect(drivers.lastLat, 6.2442);
        expect(drivers.lastLng, -75.5812);
      },
    );

    test(
      'going offline sends no fix, and going available without location '
      'permission also sends none (offline path never needs one)',
      () async {
        final drivers = instantFakeDrivers();
        final cubit = DriverHomeCubit(
          driversRepository: drivers,
          locationSource: const _FixedLocationSource(
            LatLng(lat: 6.2442, lng: -75.5812),
            permissionGranted: false,
          ),
        );

        await cubit.toggleAvailability(); // -> available, permission denied
        expect(drivers.lastLat, isNull);
        expect(drivers.lastLng, isNull);

        await cubit.toggleAvailability(); // -> offline
        expect(drivers.lastLat, isNull);
        expect(drivers.lastLng, isNull);
      },
    );

    test(
      'going available requests notification permission (TRK-3) -- '
      'best-effort, never blocks the toggle even without a requester',
      () async {
        final drivers = instantFakeDrivers();
        final requester = _RecordingNotificationPermissionRequester();
        final cubit = DriverHomeCubit(
          driversRepository: drivers,
          notificationPermissionRequester: requester,
        );

        await cubit.toggleAvailability(); // -> available
        expect(requester.requestCount, 1);
        expect(cubit.state.status, DriverStatus.available);

        await cubit.toggleAvailability(); // -> offline, no re-ask
        expect(requester.requestCount, 1);
      },
    );
  });
}
