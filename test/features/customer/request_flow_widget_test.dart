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
import 'package:the_crane/features/shared/history/history_screen.dart';
import 'package:the_crane/main.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/test_dependencies.dart';

/// CUS-4's "call driver" button deep-links out through `url_launcher`; with
/// no real platform underneath a VM widget test, an unmocked call to it
/// just throws `MissingPluginException`. Fake the platform interface
/// in-memory, mirroring how this file already fakes `Clipboard`.
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

/// Fails the next `confirmDelivery` call exactly once, mirroring
/// `RejectingOnceJobsRepository`'s shape (`test/support/`, which only
/// covers `updateJobStatus`).
class _RejectingOnceDeliveryJobsRepository extends FakeJobsRepository {
  _RejectingOnceDeliveryJobsRepository({
    super.quoteDelay,
    super.createDelay,
    super.actionDelay,
    super.matchingDelay,
  });

  bool rejectNext = false;

  @override
  Future<Job> confirmDelivery(String id, {String? paymentMethod}) {
    if (rejectNext) {
      rejectNext = false;
      return Future.error(StateError('boom'));
    }
    return super.confirmDelivery(id, paymentMethod: paymentMethod);
  }
}

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
      'FND-6: picking a Places suggestion fills the field and shows a pickup '
      'marker on the map', (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());

    await tester.enterText(find.byKey(const Key('pickupField')), 'poblado');
    await tester.pump(const Duration(milliseconds: 50)); // FakePlacesRepository (zero delay)

    final prediction = find.byKey(const Key('placePrediction_place-poblado'));
    expect(prediction, findsOneWidget);
    expect(find.byKey(const Key('craneMapMarker_pickup')), findsNothing);

    await tester.tap(prediction);
    await tester.pump(const Duration(milliseconds: 50)); // placeDetails resolves

    expect(
      tester.widget<TextField>(find.byKey(const Key('pickupField'))).controller!.text,
      'El Poblado, Medellín, Antioquia',
    );
    expect(find.byKey(const Key('placePrediction_place-poblado')), findsNothing);
    expect(find.byKey(const Key('craneMapMarker_pickup')), findsOneWidget);
  });

  testWidgets(
      'FND-6: tapping the map places pickup first, then dropoff, and dragging '
      'refines whichever pin already exists', (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());

    expect(find.byKey(const Key('craneMapMarker_pickup')), findsNothing);
    await tester.tap(find.byKey(const Key('craneMapTapArea')));
    await tester.pump();

    expect(find.byKey(const Key('craneMapMarker_pickup')), findsOneWidget);
    expect(find.byKey(const Key('craneMapMarker_dropoff')), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const Key('pickupField'))).controller!.text,
      '6.30000, -75.60000', // craneMapStubTapPosition
    );

    // A second tap places dropoff -- pickup already exists. Both fields are
    // now set, so this also fires a real (fake) quote request -- pump past
    // its quoteDelay (20ms) so the request doesn't outlive the test.
    await tester.tap(find.byKey(const Key('craneMapTapArea')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('craneMapMarker_dropoff')), findsOneWidget);

    // Both set -- the map itself no longer has a tap handler; refining
    // happens via dragging the existing pin instead.
    expect(find.byKey(const Key('craneMapTapArea')), findsNothing);

    await tester.tap(find.byKey(const Key('craneMapMarkerDrag_pickup')));
    await tester.pump(const Duration(milliseconds: 50)); // re-quotes again
    expect(
      tester.widget<TextField>(find.byKey(const Key('pickupField'))).controller!.text,
      '6.31000, -75.61000', // craneMapStubDragPosition
    );
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
    // The assigned view just mounted its map, which kicks off a (fake,
    // zero-delay) route fetch in initState -- a bare `pump()` (no duration)
    // doesn't advance FakeAsync's clock at all, so it never fires; a real
    // elapsed duration is needed to let it resolve before the test ends,
    // or its underlying Timer is still "pending" at teardown.
    await tester.pump(const Duration(milliseconds: 10));
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
      'PAY-4: choosing PSE opens the payment-method dialog, confirms, and '
      'launches the checkout redirect', (tester) async {
    final launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    final jobs = fastFakeJobs();
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      var job = page.items.single;
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
    });
    await tester.pump(const Duration(milliseconds: 10)); // watch stream

    await tester.ensureVisible(find.byKey(const Key('payDigitallyButton')));
    await tester.tap(find.byKey(const Key('payDigitallyButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentMethodPseOption')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paymentMethodPseOption')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('digitalPaymentDialogConfirmButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10)); // confirmDelivery

    expect(find.byKey(const Key('rateTripButton')), findsOneWidget);
    expect(launcher.lastLaunchedUrl, isNotNull);
    expect(launcher.lastLaunchedUrl, contains('checkout.wompi.co'));
  });

  testWidgets(
      'PAY-4: a rejected digital confirmation shows an inline error and '
      'stays on the delivered state', (tester) async {
    final jobs = fastFakeJobs();
    jobs.digitalFaresEnabled = false;
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      var job = page.items.single;
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
    });
    await tester.pump(const Duration(milliseconds: 10)); // watch stream

    await tester.ensureVisible(find.byKey(const Key('payDigitallyButton')));
    await tester.tap(find.byKey(const Key('payDigitallyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('digitalPaymentDialogConfirmButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10)); // confirmDelivery

    expect(
      find.text('Los pagos digitales no están disponibles todavía. Paga en efectivo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirmCashPaymentButton')), findsOneWidget);
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

  testWidgets('CUS-4: the call button actually dials the driver\'s phone',
      (tester) async {
    final launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
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
    await tester.ensureVisible(find.byKey(const Key('callDriverButton')));
    await tester.tap(find.byKey(const Key('callDriverButton')));
    await tester.pump();

    expect(launcher.lastLaunchedUrl, 'tel:${job!.driver!.phone}');
  });

  testWidgets('CUS-3: cancelling out of the no-drivers state goes back to '
      'the request screen', (tester) async {
    final jobs = fastFakeJobs(matchingOutcome: FakeMatchingOutcome.noDrivers);
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves
    expect(find.text('Sin grúas disponibles'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(RequestScreen), findsOneWidget);
    expect(find.byType(MatchingScreen), findsNothing);
  });

  testWidgets(
      'CUS-5: a rejected cash-payment confirmation shows an inline error',
      (tester) async {
    final jobs = _RejectingOnceDeliveryJobsRepository(
      quoteDelay: const Duration(milliseconds: 20),
      createDelay: const Duration(milliseconds: 20),
      actionDelay: const Duration(milliseconds: 10),
      matchingDelay: const Duration(milliseconds: 300),
    );
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves

    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      var job = page.items.single;
      while (job.status != JobStatus.delivered) {
        job = await jobs.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
    });
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('confirmCashPaymentButton')), findsOneWidget);

    jobs.rejectNext = true;
    await tester.ensureVisible(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.tap(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const Key('confirmCashPaymentButton')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirmCashPaymentButton')),
          )
          .onPressed,
      isNotNull,
    );

    // A later, non-rejected confirm still works normally.
    await tester.tap(find.byKey(const Key('confirmCashPaymentButton')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('confirmCashPaymentButton')), findsNothing);
    expect(find.byKey(const Key('rateTripButton')), findsOneWidget);

    // RAT-2: tapping it opens the rating dialog.
    await tester.ensureVisible(find.byKey(const Key('rateTripButton')));
    await tester.tap(find.byKey(const Key('rateTripButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'CUS-4: the status timeline shows a failure banner once the job is '
      'cancelled while still assigned', (tester) async {
    final jobs = fastFakeJobs();
    await pumpToRequestScreen(tester, jobs);
    await enterAddressesAndQuote(tester);

    await tester.ensureVisible(find.byKey(const Key('confirmRequestButton')));
    await tester.tap(find.byKey(const Key('confirmRequestButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400)); // matching resolves
    expect(find.byKey(const Key('statusTimeline')), findsOneWidget);

    // Cancelled by something other than this screen's own "leave" button
    // (which pops immediately) -- e.g. the grace-period 409 path aside,
    // any out-of-band cancellation the live `watchJob` subscription
    // delivers. `_customerCancellable` still allows it from `assigned`.
    await tester.runAsync(() async {
      final page = await jobs.listHistory(role: JobHistoryRole.customer);
      await jobs.cancelJob(page.items.single.id);
    });
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const Key('statusTimelineFailureBanner')), findsOneWidget);
    expect(find.byKey(const Key('statusTimeline')), findsNothing);
  });

  testWidgets('RAT-3: the history nav button opens the trip-history screen',
      (tester) async {
    await pumpToRequestScreen(tester, fastFakeJobs());

    await tester.tap(find.byKey(const Key('historyNavButton')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
