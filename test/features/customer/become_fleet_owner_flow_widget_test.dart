import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/models/fleet.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/become_fleet_owner_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Fails the next `createFleet` call exactly once, mirroring
/// `RejectingOnceJobsRepository`'s shape (`test/support/`).
class _RejectingOnceFleetRepository extends FakeFleetRepository {
  _RejectingOnceFleetRepository({super.actionDelay});

  bool rejectNext = false;

  @override
  Future<Fleet> createFleet({required String name}) async {
    if (rejectNext) {
      rejectNext = false;
      throw StateError('boom');
    }
    return super.createFleet(name: name);
  }
}

void main() {
  testWidgets(
      'FLT-1: a signed-in customer creates a fleet and lands on the fleet '
      'shell', (tester) async {
    await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(RequestScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('becomeFleetOwnerMenuItem')));
    await tester.pumpAndSettle();
    expect(find.byType(BecomeFleetOwnerScreen), findsOneWidget);

    // Submit is disabled until a name is entered.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeFleetOwnerSubmitButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('fleetNameField')),
      'Grúas del Valle',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeFleetOwnerSubmitButton')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('becomeFleetOwnerSubmitButton')));
    // createFleet's actionDelay + refreshUser's sync delay, then the
    // fleet cubit's own load() + the router redirect's route transition.
    // Not `pumpAndSettle`: the submit button's indeterminate
    // CircularProgressIndicator keeps animating until this screen is
    // popped by the redirect, which would hang it.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FleetHomeScreen), findsOneWidget);
    // The fake pre-links two seed trucks onto a freshly created fleet.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-1')), findsOneWidget);
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-2')), findsOneWidget);
  });

  testWidgets(
      'FLT-1: a rejected fleet creation shows an inline error and '
      're-enables the submit button', (tester) async {
    final fleet = _RejectingOnceFleetRepository(
      actionDelay: const Duration(milliseconds: 10),
    )..rejectNext = true;
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(fleet: fleet)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('becomeFleetOwnerMenuItem')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('fleetNameField')),
      'Grúas del Valle',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('becomeFleetOwnerSubmitButton')));
    await tester.pump(); // isSubmitting
    await tester.pump(const Duration(milliseconds: 20)); // actionDelay

    expect(
      find.text('No pudimos crear tu flota. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(BecomeFleetOwnerScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('becomeFleetOwnerSubmitButton')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
