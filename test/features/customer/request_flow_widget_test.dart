import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/config/env.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/truck.dart';
import 'package:the_crane/features/customer/request/matching_screen.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  // CUS-4: `Clipboard.setData`/`getData` go through `SystemChannels.platform`
  // — with no real platform underneath a VM widget test, an unmocked call
  // just never completes. Fake it in-memory so the share-trip test can
  // actually round-trip through `Clipboard`.
  String? clipboardText;
  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
        default:
          return null;
      }
    });
  });

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

  testWidgets(
      'CUS-6: picking a saved vehicle preselects its type in the quote step',
      (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());
    await enterAddressesAndQuote(tester);
    // Seeded fake vehicle veh-2 is a moto (see FakeVehiclesRepository); the
    // request draft otherwise defaults to VehicleType.car.
    await tester.pump(const Duration(milliseconds: 20)); // vehicles list load
    expect(find.byKey(const Key('savedVehicleChip_veh-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('savedVehicleChip_veh-2')));
    await tester.pump(const Duration(milliseconds: 100)); // re-quote

    final selected = tester
        .widget<SegmentedButton<VehicleType>>(
          find.byType(SegmentedButton<VehicleType>),
        )
        .selected;
    expect(selected, {VehicleType.moto});
  });

  testWidgets('CUS-3: confirm → searching → assigned driver card',
      (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
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

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
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

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
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
    // CUS-4: the status timeline (not a standalone chip) shows "Entregada"
    // as the current step.
    expect(
      tester
          .widget<Icon>(find.byKey(const Key('statusStepIcon_delivered')))
          .icon,
      Icons.radio_button_checked,
    );

    await tester.ensureVisible(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.tap(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.pump(const Duration(milliseconds: 10)); // confirmDelivery

    expect(find.byKey(const Key('confirmCashPaymentButton')), findsNothing);
    expect(find.byKey(const Key('rateTripButton')), findsOneWidget);
  });

  testWidgets(
      'CUS-4: status timeline renders with the assigned step highlighted, '
      'earlier steps unmarked', (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    expect(find.byKey(const Key('statusTimeline')), findsOneWidget);

    // Freshly assigned: the "assigned" step is current, nothing is done yet.
    final assignedIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_assigned')),
    );
    expect(assignedIcon.icon, Icons.radio_button_checked);

    final enRouteIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_en_route_pickup')),
    );
    expect(enRouteIcon.icon, Icons.radio_button_unchecked);

    final assignedLabel = tester.widget<Text>(
      find.byKey(const Key('statusStepLabel_assigned')),
    );
    expect(assignedLabel.style?.fontWeight, FontWeight.bold);
  });

  testWidgets(
      'CUS-4: advancing the job past assigned marks earlier steps done',
      (tester) async {
    final jobs = fastFakeJobs();
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    // Drive the driver-owned side of the machine forward, same as the
    // CUS-5 test above.
    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      final job = page.items.single;
      await jobs.updateJobStatus(job.id, JobStatus.enRoutePickup);
      await jobs.updateJobStatus(job.id, JobStatus.arrivedPickup);
    });
    await tester.pump(const Duration(milliseconds: 10)); // watch stream

    final assignedIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_assigned')),
    );
    expect(assignedIcon.icon, Icons.check_circle);

    final enRouteIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_en_route_pickup')),
    );
    expect(enRouteIcon.icon, Icons.check_circle);

    final arrivedIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_arrived_pickup')),
    );
    expect(arrivedIcon.icon, Icons.radio_button_checked);

    final loadingIcon = tester.widget<Icon>(
      find.byKey(const Key('statusStepIcon_loading')),
    );
    expect(loadingIcon.icon, Icons.radio_button_unchecked);
  });

  testWidgets('CUS-4: call button only shows once the driver has a phone',
      (tester) async {
    final jobs = fastFakeJobs()
      ..driverOverride = const JobDriverSummary(
        id: 'drv-002',
        name: 'Sin Teléfono',
        truckPlate: 'ABC 999',
        truckType: TruckType.car,
      );
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    expect(find.text('Sin Teléfono'), findsOneWidget);
    expect(find.byKey(const Key('callDriverButton')), findsNothing);
    // The share button doesn't depend on the phone — still shows.
    expect(find.byKey(const Key('shareTripButton')), findsOneWidget);
  });

  testWidgets('CUS-4: share button copies the track link to the clipboard',
      (tester) async {
    final jobs = fastFakeJobs();
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    final job = await tester.runAsync(
      () async => (await jobs.listHistory(role: JobHistoryRole.customer))
          .items
          .single,
    );
    expect(job!.shareToken, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('shareTripButton')));
    await tester.tap(find.byKey(const Key('shareTripButton')));
    await tester.pump();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, '${Env.webBaseUrl}/t/${job.shareToken}');
    expect(find.text('Enlace copiado al portapapeles'), findsOneWidget);
  });
}
