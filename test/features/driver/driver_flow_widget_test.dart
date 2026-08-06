import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/features/driver/job/active_job_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

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
}
