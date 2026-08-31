import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/directions_repository.dart';
import 'package:the_crane/core/api/fake_directions_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_history_page.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/utils/money_format.dart';
import 'package:the_crane/features/shared/history/history_cubit.dart';
import 'package:the_crane/features/shared/history/history_detail_screen.dart';
import 'package:the_crane/features/shared/history/history_screen.dart';
import 'package:the_crane/l10n/app_localizations.dart';

/// RAT-3 — `HistoryScreen`/`HistoryDetailScreen` don't need the full app
/// shell (no GoRouter dependency: the row-tap push is a plain
/// `Navigator.push`), just the localization delegates every screen needs
/// and the `JobsRepository`/`DirectionsRepository` (FND-6) `HistoryDetailScreen`
/// reads from context. Lighter and faster than booting `TheCraneApp` and
/// driving sign-in for a screen that's reachable without it.
Widget _app({required HistoryCubit cubit, required JobsRepository jobs}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<JobsRepository>.value(value: jobs),
      RepositoryProvider<DirectionsRepository>.value(
        value: FakeDirectionsRepository(delay: Duration.zero),
      ),
    ],
    child: BlocProvider<HistoryCubit>.value(
      value: cubit,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const HistoryScreen(),
      ),
    ),
  );
}

FakeJobsRepository _fastJobs() => FakeJobsRepository(
      quoteDelay: Duration.zero,
      createDelay: Duration.zero,
      actionDelay: Duration.zero,
      matchingDelay: Duration.zero,
    );

/// Drives one job all the way to `completed` through the seed driver,
/// mirroring `ServicesPeriodCubit`'s test helper of the same shape
/// (`test/features/driver/services_period_cubit_test.dart`).
Future<Job> _completeAJob(FakeJobsRepository jobs) async {
  final quote = await jobs.requestQuote(
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    vehicleType: VehicleType.car,
  );
  var job = await jobs.createJob(
    quoteId: quote.quoteId,
    vehicleType: VehicleType.car,
    pickup: const LatLng(lat: 6.2088, lng: -75.5679),
    pickupAddress: 'Cra. 43A #5-15, El Poblado',
    dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
    dropoffAddress: 'C.C. Mayorca, Sabaneta',
  );
  // matchingDelay is zero but still a real Timer -- needs a real
  // event-loop turn, not just Duration.zero.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  job = await jobs.getJob(job.id);
  while (job.status != JobStatus.delivered) {
    job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
  }
  return jobs.confirmDelivery(job.id);
}

/// Fails the next `listHistory` call exactly once, mirroring
/// `RejectingOnceJobsRepository`'s shape (`test/support/`) for
/// `updateJobStatus`.
class _RejectingOnceHistoryJobs extends FakeJobsRepository {
  _RejectingOnceHistoryJobs()
      : super(
          quoteDelay: Duration.zero,
          createDelay: Duration.zero,
          actionDelay: Duration.zero,
          matchingDelay: Duration.zero,
        );

  bool rejectNext = false;

  @override
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  }) {
    if (rejectNext) {
      rejectNext = false;
      return Future.error(StateError('boom'));
    }
    return super.listHistory(role: role, limit: limit, offset: offset);
  }
}

void main() {
  group('HistoryScreen (RAT-3)', () {
    testWidgets('shows a spinner while the first page is loading',
        (tester) async {
      final jobs = _fastJobs();
      final cubit = HistoryCubit(jobsRepository: jobs, role: JobHistoryRole.customer);
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      // No `pumpAndSettle` here: `CircularProgressIndicator`'s indeterminate
      // animation schedules frames forever, so settling would hang.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await cubit.close();
    });

    testWidgets('empty state shows the empty body copy', (tester) async {
      final jobs = _fastJobs();
      final cubit = HistoryCubit(jobsRepository: jobs, role: JobHistoryRole.customer)
        ..load();
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes viajes.'), findsOneWidget);
    });

    testWidgets(
        'error state shows the load-error copy and a retry button that '
        'recovers', (tester) async {
      final jobs = _RejectingOnceHistoryJobs()..rejectNext = true;
      final cubit = HistoryCubit(jobsRepository: jobs, role: JobHistoryRole.customer)
        ..load();
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar tu historial. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar tu historial. Intenta de nuevo.'),
        findsNothing,
      );
      expect(find.text('Aún no tienes viajes.'), findsOneWidget);
    });

    testWidgets('list state renders a row per completed job', (tester) async {
      final jobs = _fastJobs();
      // `runAsync` escapes the test's fake-async zone so `_completeAJob`'s
      // real `Future.delayed`-backed fake-repository calls actually resolve
      // (same gotcha `request_flow_widget_test.dart` documents).
      final job = (await tester.runAsync(() => _completeAJob(jobs)))!;
      final cubit = HistoryCubit(jobsRepository: jobs, role: JobHistoryRole.customer)
        ..load();
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('historyRow_${job.id}')), findsOneWidget);
      expect(
        find.textContaining('Cra. 43A #5-15, El Poblado'),
        findsOneWidget,
      );
      expect(find.text(formatCop(job.finalPrice ?? job.quotedPrice)), findsOneWidget);
      expect(find.text('Completada'), findsOneWidget);
    });

    testWidgets('a load-more button appears while more pages remain, and '
        'tapping it appends the next page', (tester) async {
      final jobs = _fastJobs();
      await tester.runAsync(() async {
        await _completeAJob(jobs);
        await _completeAJob(jobs);
        await _completeAJob(jobs);
      });
      final cubit = HistoryCubit(
        jobsRepository: jobs,
        role: JobHistoryRole.customer,
        pageSize: 2,
      )..load();
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.byKey(const Key('historyLoadMoreButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('historyLoadMoreButton')));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.byKey(const Key('historyLoadMoreButton')), findsNothing);
    });

    testWidgets('tapping a row opens the detail screen for that job',
        (tester) async {
      final jobs = _fastJobs();
      final job = (await tester.runAsync(() => _completeAJob(jobs)))!;
      final cubit = HistoryCubit(jobsRepository: jobs, role: JobHistoryRole.customer)
        ..load();
      await tester.pumpWidget(_app(cubit: cubit, jobs: jobs));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('historyRow_${job.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      expect(find.text('Detalle del viaje'), findsOneWidget);
    });
  });
}
