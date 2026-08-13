import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_history_page.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/driver/earnings/earnings_screen.dart';
import 'package:the_crane/features/driver/earnings/services_period_cubit.dart';
import 'package:the_crane/features/driver/earnings/services_period_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  setUp(ServicesPeriodCubit.resetRememberedFilterForTest);

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
        vehicleType: VehicleType.car,
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        pickupAddress: 'Origin',
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
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

    // DRV-6: the "custom" segment opens a date-range picker instead of
    // switching the filter directly; picking a range switches to it (and
    // the range button then shows the picked dates instead of the
    // "pick a range" placeholder).
    await tester.tap(find.text('Personalizado'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);

    // Days 1-5 of the current month are always safely in the past (this
    // test doesn't run on the 1st-4th, but if it ever does, `lastDate` is
    // `now` and the picker would just clamp -- not worth chasing that edge
    // for a fixed test date).
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<ServicesPeriodFilter>>(
            find.byKey(const Key('servicesPeriodFilterSelector')),
          )
          .selected,
      {ServicesPeriodFilter.custom},
    );
    expect(find.text('Elegir rango de fechas'), findsNothing);
    expect(find.byKey(const Key('servicesPeriodCustomRangeButton')), findsOneWidget);

    // Reopening the picker (already on `custom`) pre-fills it with the
    // range just picked, instead of starting from nothing.
    await tester.tap(find.byKey(const Key('servicesPeriodCustomRangeButton')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('servicesPeriodCustomRangeButton')), findsOneWidget);
  });

  testWidgets('DRV-6: a failed load offers retry, which then succeeds',
      (tester) async {
    final jobs = _FlakyHistoryJobs(matchingDelay: Duration.zero)
      ..rejectLoads = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('servicesPeriodNavButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar tus servicios. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('servicesPeriodTotalsCard')), findsNothing);

    jobs.rejectLoads = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes servicios completados.'), findsOneWidget);
  });
}

/// Lets `listHistory` be forced to fail, so DRV-6's error/retry state is
/// reachable without a real backend. Deliberately sticky (cleared
/// explicitly by the test, not consumed on first use like
/// `RejectingOnceJobsRepository`, `test/support/`): the `services` route's
/// `BlocProvider(create: ...  ..load())` fires more than once per
/// navigation here (go_router builds the destination page ahead of the
/// transition settling), so a single-shot flag risks being consumed by a
/// load the assertions never observe -- same issue worked around in
/// `saved_vehicles_flow_widget_test.dart`.
class _FlakyHistoryJobs extends FakeJobsRepository {
  _FlakyHistoryJobs({super.matchingDelay});

  bool rejectLoads = false;

  @override
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  }) {
    if (rejectLoads) return Future.error(StateError('boom'));
    return super.listHistory(role: role, limit: limit, offset: offset);
  }
}
