import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets(
      'FLT-3: a signed-in fleet owner sees their trucks with status at a '
      'glance', (tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.fleetOwner)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    expect(find.byType(FleetHomeScreen), findsOneWidget);
    // Seeded fleet: one truck with an available driver, one offline.
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-1')), findsOneWidget);
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-2')), findsOneWidget);
    expect(find.text('Camilo Ríos · Disponible'), findsOneWidget);
    expect(find.text('Laura Gómez · Desconectado'), findsOneWidget);
  });
}
