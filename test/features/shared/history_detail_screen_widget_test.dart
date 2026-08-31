import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/directions_repository.dart';
import 'package:the_crane/core/api/fake_directions_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/rating.dart';
import 'package:the_crane/core/utils/money_format.dart';
import 'package:the_crane/features/shared/history/history_detail_screen.dart';
import 'package:the_crane/l10n/app_localizations.dart';

/// RAT-3 — no GoRouter dependency (it's just pushed via `Navigator.push` by
/// `HistoryScreen`), so it's exercised standalone here with only the
/// localization delegates and the `JobsRepository`/`DirectionsRepository`
/// (FND-6, the map's route line) it reads from context.
Widget _app({required Job job, required JobsRepository jobs}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<JobsRepository>.value(value: jobs),
      RepositoryProvider<DirectionsRepository>.value(
        value: FakeDirectionsRepository(delay: Duration.zero),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: HistoryDetailScreen(job: job),
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
/// (`test/features/driver/services_period_cubit_test.dart`). Registers the
/// job in the fake repository's own store, which `submitRating` requires.
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
  await Future<void>.delayed(const Duration(milliseconds: 10));
  job = await jobs.getJob(job.id);
  while (job.status != JobStatus.delivered) {
    job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
  }
  return jobs.confirmDelivery(job.id);
}

/// Wraps a [FakeJobsRepository] to hand back a driver-authored rating --
/// `FakeJobsRepository.submitRating` only ever records the customer rating
/// the driver (no real current-user concept yet -- AUTH-3/4), so the
/// "driver rating the customer" label can't be reached through its real
/// `submitRating`/`getRatings` round trip.
class _DriverRatingJobs extends FakeJobsRepository {
  _DriverRatingJobs({super.quoteDelay, super.createDelay, super.actionDelay, super.matchingDelay});

  Rating? ratingOverride;

  @override
  Future<List<Rating>> getRatings(String jobId) async =>
      ratingOverride == null ? const [] : [ratingOverride!];
}

void main() {
  group('HistoryDetailScreen (RAT-3)', () {
    testWidgets('renders a completed job\'s full detail with no ratings yet',
        (tester) async {
      final jobs = _fastJobs();
      final job = (await tester.runAsync(() => _completeAJob(jobs)))!;

      await tester.pumpWidget(_app(job: job, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del viaje'), findsOneWidget);
      expect(
        tester
            .widget<Chip>(find.byKey(const Key('historyDetailStatusChip')))
            .label,
        isA<Text>().having((t) => t.data, 'data', 'Completada'),
      );
      expect(find.text('Cra. 43A #5-15, El Poblado'), findsOneWidget);
      expect(find.text('C.C. Mayorca, Sabaneta'), findsOneWidget);
      expect(find.text(formatCop(job.finalPrice ?? job.quotedPrice)), findsOneWidget);
      expect(find.text('Calificaciones'), findsOneWidget);
      expect(find.text('Sin calificaciones todavía.'), findsOneWidget);
      expect(find.byKey(const Key('historyRatingsList')), findsNothing);
    });

    testWidgets(
        'renders the submitted rating, labeled as the customer rating the '
        'driver', (tester) async {
      final jobs = _fastJobs();
      final job = (await tester.runAsync(() async {
        final completed = await _completeAJob(jobs);
        await jobs.submitRating(completed.id, stars: 4, comment: 'Muy amable');
        return completed;
      }))!;

      await tester.pumpWidget(_app(job: job, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('historyRatingsList')), findsOneWidget);
      expect(find.text('Sin calificaciones todavía.'), findsNothing);
      // `FakeJobsRepository.submitRating` always records the customer rating
      // the driver (no real current-user concept yet -- AUTH-3/4).
      expect(find.text('Calificación al conductor'), findsOneWidget);
      expect(find.text('Muy amable'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('labels a driver-authored rating as rating the customer',
        (tester) async {
      final jobs = _DriverRatingJobs(
        quoteDelay: Duration.zero,
        createDelay: Duration.zero,
        actionDelay: Duration.zero,
        matchingDelay: Duration.zero,
      );
      final job = (await tester.runAsync(() => _completeAJob(jobs)))!;
      jobs.ratingOverride = Rating(
        id: 'rat-1',
        jobId: job.id,
        fromUserId: job.driverId!,
        toUserId: job.customerId,
        stars: 5,
        comment: 'Cliente muy puntual',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(_app(job: job, jobs: jobs));
      await tester.pumpAndSettle();

      expect(find.text('Calificación al cliente'), findsOneWidget);
      expect(find.text('Cliente muy puntual'), findsOneWidget);
    });
  });
}
