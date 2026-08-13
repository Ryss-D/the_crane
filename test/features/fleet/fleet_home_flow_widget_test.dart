import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/fleet.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/features/fleet/truck_detail/fleet_truck_detail_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Lets a single `getMyFleet` call be forced to fail (mirroring
/// `RejectingOnceJobsRepository`'s shape, `test/support/`) or to come back
/// with no trucks, so FLT-3's error/retry and empty states are reachable
/// without a real backend.
class _FlakyHomeFleetRepository extends FakeFleetRepository {
  _FlakyHomeFleetRepository({super.auth, super.actionDelay, super.seeded});

  bool rejectNextFleet = false;
  bool emptyTrucks = false;

  @override
  Future<Fleet> getMyFleet() async {
    if (rejectNextFleet) {
      rejectNextFleet = false;
      throw StateError('boom');
    }
    final fleet = await super.getMyFleet();
    return emptyTrucks ? fleet.copyWith(trucks: const []) : fleet;
  }
}

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

  testWidgets('FLT-3: tapping a truck goes to its detail view', (tester) async {
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(authRole: UserRole.fleetOwner)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('fleetTruckRow_trk-fleet-1')));
    await tester.pumpAndSettle();

    expect(find.byType(FleetTruckDetailScreen), findsOneWidget);
    expect(find.text('FLT001'), findsOneWidget);
    expect(find.text('Camilo Ríos'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
  });

  testWidgets('FLT-3: a failed load offers retry, which then succeeds',
      (tester) async {
    final fleet = _FlakyHomeFleetRepository(
      seeded: true,
      actionDelay: const Duration(milliseconds: 10),
    )..rejectNextFleet = true;
    await tester.pumpWidget(
      TheCraneApp(
        dependencies:
            testDependencies(authRole: UserRole.fleetOwner, fleet: fleet),
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    expect(
      find.text('No pudimos cargar tu flota. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-1')), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fleetTruckRow_trk-fleet-1')), findsOneWidget);
  });

  testWidgets('FLT-3: a fleet with no trucks yet shows the empty body',
      (tester) async {
    final fleet = _FlakyHomeFleetRepository(
      seeded: true,
      actionDelay: const Duration(milliseconds: 10),
    )..emptyTrucks = true;
    await tester.pumpWidget(
      TheCraneApp(
        dependencies:
            testDependencies(authRole: UserRole.fleetOwner, fleet: fleet),
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    expect(
      find.text('Tu flota aún no tiene grúas. Agrega una con su placa.'),
      findsOneWidget,
    );
  });
}
