import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/customer/request/matching_screen.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  Future<void> pumpToRequestScreen(
    WidgetTester tester,
    FakeJobsRepository jobs,
  ) async {
    await tester
        .pumpWidget(TheCraneApp(dependencies: testDependencies(jobs: jobs)));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(RequestScreen), findsOneWidget);
  }

  Future<void> enterAddressesAndQuote(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('pickupField')),
      'Calle 10 #43E-31, El Poblado',
    );
    await tester.enterText(
      find.byKey(const Key('dropoffField')),
      'Cra. 48 #32B Sur, Envigado',
    );
    // quoteDelay (20ms) elapses.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('quotePrice')), findsOneWidget);
  }

  testWidgets('CUS-1/2: quote appears in COP after entering the trip',
      (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());
    await enterAddressesAndQuote(tester);

    final priceText =
        tester.widget<Text>(find.byKey(const Key('quotePrice'))).data!;
    expect(priceText, startsWith(r'$'));
    expect(priceText, contains('.')); // es_CO thousands grouping.

    // Vehicle selector is present with all three options.
    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('Carro'), findsOneWidget);
    expect(find.text('SUV'), findsOneWidget);
  });

  testWidgets('CUS-3: confirm → searching → assigned driver card',
      (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());
    await enterAddressesAndQuote(tester);

    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50)); // createDelay
    await tester.pump(const Duration(milliseconds: 400)); // route transition

    expect(find.byType(MatchingScreen), findsOneWidget);
    expect(find.text('Buscando tu grúa'), findsWidgets);

    // matchingDelay (300ms) elapses → assigned.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¡Grúa asignada!'), findsOneWidget);
    expect(find.text('Carlos Ramírez'), findsOneWidget);
    expect(find.textContaining('Placa TGX 123'), findsOneWidget);
  });

  testWidgets('CUS-3: no-drivers state offers retry', (tester) async {
    final jobs = fastFakeJobs(matchingOutcome: FakeMatchingOutcome.noDrivers);
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    expect(find.text('Sin grúas disponibles'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    // Retry with a driver now available.
    jobs.matchingOutcome = FakeMatchingOutcome.assigned;
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Buscando tu grúa'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¡Grúa asignada!'), findsOneWidget);
  });

  testWidgets(
      'CUS-5: delivered shows the fare and a cash-confirm button that '
      'completes the job', (tester) async {
    final jobs = fastFakeJobs();
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves
    expect(find.byType(MatchingScreen), findsOneWidget);

    // Drive the driver-owned side of the machine up to `delivered` directly
    // through the repository, same as the real driver app would. `runAsync`
    // escapes the test's fake-async zone so these real `Future.delayed`
    // -backed fake calls actually resolve.
    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      var job = page.items.single;
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
    });
    await tester.pump(const Duration(milliseconds: 10)); // watch stream

    expect(find.byKey(const Key('confirmCashPaymentButton')), findsOneWidget);
    expect(find.text('Entregada'), findsNothing); // no status chip here

    await tester.tap(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.pump(const Duration(milliseconds: 10)); // confirmDelivery

    expect(find.byKey(const Key('confirmCashPaymentButton')), findsNothing);
    expect(find.byKey(const Key('rateTripButton')), findsOneWidget);
  });
}
