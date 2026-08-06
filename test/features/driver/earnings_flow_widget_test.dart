import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/driver/earnings/earnings_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
      'DRV-5: earnings screen shows the owed balance and recent settlement',
      (tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.driver)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(DriverHomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();

    expect(find.byType(EarningsScreen), findsOneWidget);
    expect(find.byKey(const Key('earningsOwedAmount')), findsOneWidget);
    // The fake seeds exactly one settlement.
    expect(find.byKey(const Key('settlementRow_set-1')), findsOneWidget);
  });
}
