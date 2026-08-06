import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/fleet/balance/fleet_balance_screen.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
      'FLT-5: fleet earnings screen shows the consolidated balance and '
      'per-driver breakdown', (tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.fleetOwner)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(FleetHomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('fleetBalanceNavButton')));
    await tester.pumpAndSettle();

    expect(find.byType(FleetBalanceScreen), findsOneWidget);
    expect(find.byKey(const Key('fleetBalanceOwedAmount')), findsOneWidget);
    // The fake seeds exactly two members.
    expect(
      find.byKey(const Key('fleetMemberBalanceRow_drv-fleet-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fleetMemberBalanceRow_drv-fleet-2')),
      findsOneWidget,
    );
  });
}
