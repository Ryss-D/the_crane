import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/driver_balance.dart';
import 'package:the_crane/features/driver/earnings/earnings_screen.dart';
import 'package:the_crane/features/driver/home/driver_home_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Lets `balance` be forced to fail, or to come back with a caller-chosen
/// shape, so DRV-5's error/retry state and the cap/no-settlements/
/// no-note-settlement branches (none of which the seeded fake balance ever
/// takes) are all reachable without a real backend. `rejectLoads` is
/// deliberately sticky (cleared explicitly by the test, not consumed on
/// first use like `RejectingOnceJobsRepository`, `test/support/`): this
/// route's `BlocProvider(create: ...  ..load())` fires more than once per
/// navigation (go_router builds the destination page ahead of the
/// transition settling), so a single-shot flag risks being consumed by a
/// load the assertions never observe.
class _FlakyEarningsDriversRepository extends FakeDriversRepository {
  _FlakyEarningsDriversRepository({required super.jobs, super.actionDelay});

  bool rejectLoads = false;
  DriverBalance? overrideBalance;

  @override
  Future<DriverBalance> balance() async {
    if (rejectLoads) throw StateError('boom');
    if (overrideBalance != null) return overrideBalance!;
    return super.balance();
  }
}

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

  testWidgets('DRV-5: a failed load offers retry, which then succeeds',
      (tester) async {
    final drivers = _FlakyEarningsDriversRepository(
      jobs: fastFakeJobs(),
      actionDelay: const Duration(milliseconds: 10),
    )..rejectLoads = true;
    await tester.pumpWidget(TheCraneApp(
      dependencies:
          testDependencies(drivers: drivers, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar tus ganancias. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('earningsOwedAmount')), findsNothing);

    drivers.rejectLoads = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('earningsOwedAmount')), findsOneWidget);
  });

  testWidgets(
      'DRV-5: a balance cap shows its label, and no settlements yet shows '
      'the empty body', (tester) async {
    final drivers = _FlakyEarningsDriversRepository(
      jobs: fastFakeJobs(),
      actionDelay: const Duration(milliseconds: 10),
    )..overrideBalance = const DriverBalance(
        owedCents: 50000,
        balanceCapCents: 100000,
      );
    await tester.pumpWidget(TheCraneApp(
      dependencies:
          testDependencies(drivers: drivers, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Límite de saldo antes de bloquear disponibilidad'),
      findsOneWidget,
    );
    expect(find.text('Aún no hay liquidaciones.'), findsOneWidget);
  });

  testWidgets('DRV-5: a settlement with no note shows just its date',
      (tester) async {
    final settledAt = DateTime(2026, 1, 5);
    final drivers = _FlakyEarningsDriversRepository(
      jobs: fastFakeJobs(),
      actionDelay: const Duration(milliseconds: 10),
    )..overrideBalance = DriverBalance(
        owedCents: 0,
        recentSettlements: [
          Settlement(id: 'set-no-note', amountCents: 5000, settledAt: settledAt),
        ],
      );
    await tester.pumpWidget(TheCraneApp(
      dependencies:
          testDependencies(drivers: drivers, authRole: UserRole.driver),
    ));
    await tester.pumpAndSettle();
    await signIn(tester);

    await tester.tap(find.byKey(const Key('earningsNavButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settlementRow_set-no-note')), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });
}
