import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/driver/earnings/earnings_screen.dart';
import 'package:the_crane/features/driver/earnings/services_period_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
      'DRV-6: services-per-period screen, reachable from earnings, shows a '
      'completed job grouped under today', (tester) async {
    final jobs = fastFakeJobs(matchingDelay: Duration.zero);
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(DriverHomeScreen), findsOneWidget);

    // Complete one job directly through the repository (same shape as the
    // DRV-4 test) -- `runAsync` escapes the fake-async zone so these real
    // `Future.delayed`-backed fake calls resolve.
    await tester.runAsync(() async {
      final quote = await jobs.requestQuote(
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
        vehicleType: VehicleType.car,
      );
      var job = await jobs.createJob(
        quoteId: quote.quoteId,
        pickupAddress: 'Origin',
        dropoffAddress: 'Destination',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      job = await jobs.getJob(job.id);
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
      await jobs.confirmDelivery(job.id);
    });

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(EarningsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('servicesPeriodNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(ServicesPeriodScreen), findsOneWidget);

    // Defaults to "today" -- the job just completed shows up there.
    expect(find.text('1 servicios'), findsOneWidget);

    // DRV-6: switching the period filter updates the totals/list together.
    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    expect(find.text('1 servicios'), findsOneWidget);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.text('1 servicios'), findsOneWidget);
  });
}
