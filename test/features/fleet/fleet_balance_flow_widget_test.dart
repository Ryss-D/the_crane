import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_fleet_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/fleet.dart';
import 'package:the_crane/features/fleet/balance/fleet_balance_screen.dart';
import 'package:the_crane/features/fleet/home/fleet_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Lets a single `getBalance` call be forced to fail (mirroring
/// `RejectingOnceJobsRepository`'s shape, `test/support/`) or to come back
/// with no members, so FLT-5's error/retry and empty states are reachable
/// without a real backend.
class _FlakyBalanceFleetRepository extends FakeFleetRepository {
  _FlakyBalanceFleetRepository({super.auth, super.actionDelay, super.seeded});

  bool rejectNextBalance = false;
  bool emptyMembers = false;

  @override
  Future<FleetBalance> getBalance() async {
    if (rejectNextBalance) {
      rejectNextBalance = false;
      throw StateError('boom');
    }
    final balance = await super.getBalance();
    return emptyMembers ? balance.copyWith(members: const []) : balance;
  }
}

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

  testWidgets('FLT-5: a failed load offers retry, which then succeeds',
      (tester) async {
    final fleet = _FlakyBalanceFleetRepository(
      seeded: true,
      actionDelay: const Duration(milliseconds: 10),
    )..rejectNextBalance = true;
    await tester.pumpWidget(
      TheCraneApp(
        dependencies:
            testDependencies(authRole: UserRole.fleetOwner, fleet: fleet),
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(FleetHomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('fleetBalanceNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(FleetBalanceScreen), findsOneWidget);

    expect(
      find.text('No pudimos cargar las ganancias de la flota. Intenta de '
          'nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fleetBalanceOwedAmount')), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fleetBalanceOwedAmount')), findsOneWidget);
    expect(
      find.byKey(const Key('fleetMemberBalanceRow_drv-fleet-1')),
      findsOneWidget,
    );
  });

  testWidgets('FLT-5: a fleet with no member balances shows the empty body',
      (tester) async {
    final fleet = _FlakyBalanceFleetRepository(
      seeded: true,
      actionDelay: const Duration(milliseconds: 10),
    )..emptyMembers = true;
    await tester.pumpWidget(
      TheCraneApp(
        dependencies:
            testDependencies(authRole: UserRole.fleetOwner, fleet: fleet),
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('fleetBalanceNavButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fleetBalanceOwedAmount')), findsOneWidget);
    expect(
      find.text('Tu flota aún no tiene conductores con saldo.'),
      findsOneWidget,
    );
  });
}
