import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/fleet/add_truck/add_truck_screen.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  Future<void> pumpToFleetHome(WidgetTester tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.fleetOwner)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(FleetHomeScreen), findsOneWidget);
  }

  testWidgets('FLT-4: attaches an unclaimed truck found by plate',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('addTruckButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AddTruckScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('addTruckPlateField')),
      'NEW001',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('addTruckSearchButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Once, in the found-truck card -- the plate field itself also shows
    // "NEW001" (what was typed), hence findsOneWidget rather than
    // deduplicating both matches away.
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('NEW001'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('addTruckAttachButton')), findsOneWidget);
    expect(find.byKey(const Key('addTruckAlreadyClaimedText')), findsNothing);

    await tester.tap(find.byKey(const Key('addTruckAttachButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(FleetHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('fleetTruckRow_trk-unclaimed-1')), findsOneWidget);
  });

  testWidgets('FLT-4: shows a clear message for an already-claimed truck',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('addTruckButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('addTruckPlateField')),
      'OTR001',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('addTruckSearchButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addTruckAlreadyClaimedText')), findsOneWidget);
    expect(find.byKey(const Key('addTruckAttachButton')), findsNothing);
  });

  testWidgets('FLT-4: shows a not-found message for an unknown plate',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('addTruckButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('addTruckPlateField')),
      'NOPE00',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('addTruckSearchButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addTruckNotFoundText')), findsOneWidget);
  });

  testWidgets('FLT-4: detaches a truck from the fleet after confirmation',
      (tester) async {
    await pumpToFleetHome(tester);

    await tester.tap(find.byKey(const Key('fleetTruckRow_trk-fleet-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detachTruckButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDetachButton')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(FleetHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-1')), findsNothing);
  });
}
