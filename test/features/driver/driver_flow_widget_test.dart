import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/features/driver/job/active_job_screen.dart';
import 'package:the_crane/features/shared/history/history_screen.dart';
import 'package:the_crane/main.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/rejecting_jobs_repository.dart';
import '../../support/test_dependencies.dart';

/// DRV-3's "navigate" button deep-links out through `url_launcher`; with no
/// real platform underneath a VM widget test, an unmocked call to it just
/// throws `MissingPluginException`. Fake the platform interface in-memory,
/// mirroring how `request_flow_widget_test.dart` fakes `Clipboard`.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  String? lastLaunchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return true;
  }
}

void main() {
  Future<void> pumpToDriverHome(WidgetTester tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.driver)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(DriverHomeScreen), findsOneWidget);
  }

  Future<void> goAvailable(WidgetTester tester) async {
    expect(find.text('Desconectado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('availabilityToggle')));
    await tester.pump(); // isUpdating
    await tester.pump(const Duration(milliseconds: 50)); // actionDelay
    expect(find.text('Disponible'), findsOneWidget);
  }

  testWidgets('DRV-1: availability toggle drives the repository status',
      (tester) async {
    await pumpToDriverHome(tester);
    await goAvailable(tester);

    // Toggle back offline.
    await tester.tap(find.byKey(const Key('availabilityToggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Desconectado'), findsOneWidget);
    // Dev offer trigger is disabled while offline.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('devTriggerOfferButton')),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets(
      'DRV-1: a balance-cap rejection on going available shows its own '
      'banner and leaves the driver offline', (tester) async {
    final jobs = FakeJobsRepository(actionDelay: const Duration(milliseconds: 10));
    final drivers = FakeDriversRepository(
      jobs: jobs,
      actionDelay: const Duration(milliseconds: 10),
    )..rejectNextAvailableWithBalanceCap = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(
        jobs: jobs,
        drivers: drivers,
        authRole: UserRole.driver,
      ),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(DriverHomeScreen), findsOneWidget);

    expect(find.text('Desconectado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('availabilityToggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20)); // actionDelay

    // Rejected: still offline, and the balance-cap banner shows.
    expect(find.text('Desconectado'), findsOneWidget);
    expect(
      find.text(
        'Tu saldo pendiente superó el límite permitido. Paga tu saldo '
        'para volver a conectarte.',
      ),
      findsOneWidget,
    );

    // A later toggle (cap lifted) succeeds normally and clears the banner.
    await tester.tap(find.byKey(const Key('availabilityToggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Disponible'), findsOneWidget);
    expect(
      find.text(
        'Tu saldo pendiente superó el límite permitido. Paga tu saldo '
        'para volver a conectarte.',
      ),
      findsNothing,
    );
  });

  testWidgets(
      'DRV-2/3/4: offer sheet → accept → active job advances to delivered, '
      'then the customer\'s confirm-delivery completes it live',
      (tester) async {
    final jobs = fastFakeJobs();
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(DriverHomeScreen), findsOneWidget);
    await goAvailable(tester);

    // Trigger a fake incoming offer; the bottom sheet appears.
    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet animation
    expect(find.text('Nueva oferta de servicio'), findsOneWidget);
    expect(find.text('Tarifa'), findsOneWidget);
    expect(find.text('Comisión plataforma'), findsOneWidget);
    expect(find.textContaining('Expira en'), findsOneWidget);

    // Accept → sheet closes, active job screen opens on `assigned`.
    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50)); // accept delay
    await tester.pump(const Duration(milliseconds: 400)); // pop + push
    expect(find.byType(ActiveJobScreen), findsOneWidget);
    expect(find.text('Asignada'), findsOneWidget);

    // Cycle the driver-owned part of the state machine: En camino → ... →
    // Entregado. `delivered` is as far as the driver's own advance button
    // goes (CUS-5/DRV-4) — completion is the customer's cash confirmation.
    final expectedButtonLabels = [
      'En camino',
      'Llegué',
      'Cargando vehículo',
      'En ruta',
      'Entregado',
    ];
    for (final label in expectedButtonLabels) {
      expect(find.text(label), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
      await tester.tap(find.byKey(const Key('advanceStatusButton')));
      await tester.pump(const Duration(milliseconds: 50)); // actionDelay
    }
    expect(find.text('Entregada'), findsOneWidget);
    expect(find.byKey(const Key('advanceStatusButton')), findsNothing);
    expect(
      find.text('Esperando que el cliente confirme el pago en efectivo.'),
      findsOneWidget,
    );

    // Simulates the customer confirming cash payment (CUS-5) from their own
    // screen — the driver never calls this. `ActiveJobCubit`'s `watchJob`
    // subscription (DRV-4) should flip this same screen to `done` live.
    // `runAsync` escapes the test's fake-async zone so these real
    // `Future.delayed`-backed fake calls actually resolve (`tester.pump`
    // alone only advances the fake clock, it doesn't drive real timers).
    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.driver);
      await jobs.confirmDelivery(page.items.single.id);
    });
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Servicio finalizado. ¡Buen trabajo!'), findsOneWidget);

    // DRV-4 AC: commission for this job + the fresh running balance.
    expect(find.byKey(const Key('jobCommissionAmount')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30)); // balance() fetch
    expect(find.byKey(const Key('runningBalanceAmount')), findsOneWidget);

    // Back home, ready for the next job.
    await tester.ensureVisible(find.byKey(const Key('backToHomeButton')));
    await tester.tap(find.byKey(const Key('backToHomeButton')));
    await tester.pumpAndSettle();
    expect(find.byType(DriverHomeScreen), findsOneWidget);
  });

  testWidgets('DRV-2: offer countdown timeout auto-dismisses the sheet',
      (tester) async {
    await pumpToDriverHome(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nueva oferta de servicio'), findsOneWidget);

    // Let the full 30s TTL elapse → auto-dismissed, no navigation.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 400)); // close animation
    expect(find.text('Nueva oferta de servicio'), findsNothing);
    expect(find.byType(ActiveJobScreen), findsNothing);
    expect(find.byType(DriverHomeScreen), findsOneWidget);
  });

  testWidgets(
      'DRV-3: a rejected advance() shows the backend message and leaves '
      'the job on its current status', (tester) async {
    final jobs = RejectingOnceJobsRepository(
      actionDelay: const Duration(milliseconds: 10),
    );
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet animation

    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50)); // accept delay
    await tester.pump(const Duration(milliseconds: 400)); // pop + push
    expect(find.byType(ActiveJobScreen), findsOneWidget);
    expect(find.text('Asignada'), findsOneWidget);

    jobs.rejectNext = true;
    await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
    await tester.tap(find.byKey(const Key('advanceStatusButton')));
    await tester.pump(const Duration(milliseconds: 20)); // actionDelay
    await tester.pump(); // SnackBar animation

    expect(
      find.text('Drivers cannot set status en_route_pickup'),
      findsWidgets,
    );
    // The job didn't move — still `assigned`, advance button still shows
    // the same "En camino" action.
    expect(find.text('Asignada'), findsOneWidget);
    expect(find.text('En camino'), findsOneWidget);

    // A later, non-rejected advance still works normally.
    await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
    await tester.tap(find.byKey(const Key('advanceStatusButton')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('En camino a la recogida'), findsOneWidget);
  });

  testWidgets(
      'DRV-3: the navigate button deep-links to the current leg\'s point',
      (tester) async {
    final launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    final jobs = fastFakeJobs();
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ActiveJobScreen), findsOneWidget);

    // `assigned`: still on the way to pickup, so the target is the pickup
    // point, not the dropoff.
    final job = await tester.runAsync(
      () async => (await jobs.listHistory(role: JobHistoryRole.driver))
          .items
          .single,
    );
    await tester.tap(find.byKey(const Key('navigateButton')));
    await tester.pump();

    expect(
      launcher.lastLaunchedUrl,
      'https://www.google.com/maps/dir/?api=1&destination='
      '${job!.pickup.lat},${job.pickup.lng}',
    );

    // Advance past `arrived_pickup`: once loading starts, the leg (and the
    // navigate target) flips to the dropoff point.
    await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
    await tester.tap(find.byKey(const Key('advanceStatusButton'))); // en_route
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
    await tester.tap(find.byKey(const Key('advanceStatusButton'))); // arrived
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.byKey(const Key('advanceStatusButton')));
    await tester.tap(find.byKey(const Key('advanceStatusButton'))); // loading
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.byKey(const Key('navigateButton')));
    await tester.tap(find.byKey(const Key('navigateButton')));
    await tester.pump();
    expect(
      launcher.lastLaunchedUrl,
      'https://www.google.com/maps/dir/?api=1&destination='
      '${job.dropoff.lat},${job.dropoff.lng}',
    );
  });

  testWidgets('DRV-3: the call-customer button actually dials the customer\'s '
      'phone', (tester) async {
    final launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    final jobs = fastFakeJobs();
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ActiveJobScreen), findsOneWidget);

    final job = await tester.runAsync(
      () async => (await jobs.listHistory(role: JobHistoryRole.driver))
          .items
          .single,
    );
    await tester.ensureVisible(find.byKey(const Key('callCustomerButton')));
    await tester.tap(find.byKey(const Key('callCustomerButton')));
    await tester.pump();

    expect(launcher.lastLaunchedUrl, 'tel:${job!.customer!.phone}');
  });

  testWidgets(
      'DRV-3: cancel is confirm-dialog-gated -- dismissing it leaves the job '
      'untouched, confirming it returns the job to matching and this screen '
      'to its no-active-job state', (tester) async {
    final jobs = fastFakeJobs();
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ActiveJobScreen), findsOneWidget);
    // `assigned` is driver-cancellable.
    expect(find.byKey(const Key('cancelJobButton')), findsOneWidget);

    // Dismiss: job is untouched.
    await tester.ensureVisible(find.byKey(const Key('cancelJobButton')));
    await tester.tap(find.byKey(const Key('cancelJobButton')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar este servicio?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Asignada'), findsOneWidget);
    expect(find.byKey(const Key('cancelJobButton')), findsOneWidget);

    // Confirm: the job is cancelled (back to matching, per
    // `DRIVER_CANCELLABLE`) and `ActiveJobCubit`'s state clears -- this
    // screen falls back to its no-active-job view.
    await tester.tap(find.byKey(const Key('cancelJobButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmCancelJobButton')));
    await tester.pump(const Duration(milliseconds: 20)); // cancelJob's delay

    expect(find.byKey(const Key('jobStatusChip')), findsNothing);
    expect(find.text('Volver al inicio'), findsOneWidget);

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverHomeScreen), findsOneWidget);
  });

  testWidgets('DRV-4/RAT-2: the completed job\'s rate-trip button opens the '
      'rating dialog', (tester) async {
    final jobs = fastFakeJobs();
    await tester.pumpWidget(TheCraneApp(
      dependencies: testDependencies(jobs: jobs, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);
    await goAvailable(tester);

    await tester.tap(find.byKey(const Key('devTriggerOfferButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('acceptOfferButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.driver);
      var job = page.items.single;
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
      await jobs.confirmDelivery(job.id);
    });
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('rateTripButton')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('rateTripButton')));
    await tester.tap(find.byKey(const Key('rateTripButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('RAT-3: the history nav button opens the trip-history screen',
      (tester) async {
    await pumpToDriverHome(tester);

    await tester.tap(find.byKey(const Key('historyNavButton')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
