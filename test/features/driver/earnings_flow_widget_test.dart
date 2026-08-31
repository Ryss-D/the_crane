import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/models/app_user.dart';
import 'package:the_crane/core/models/driver_balance.dart';
import 'package:the_crane/core/utils/money_format.dart';
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

  /// PAY-3: records the args the screen actually sent, so a test can assert
  /// on them without needing a real amount/method picked through the UI.
  ({int amountCop, SettlementPaymentMethod method})? lastSettleCall;

  @override
  Future<SettlementCheckout> settleBalance({
    required int amountCop,
    SettlementPaymentMethod method = SettlementPaymentMethod.nequi,
  }) {
    lastSettleCall = (amountCop: amountCop, method: method);
    return super.settleBalance(amountCop: amountCop, method: method);
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

  group('PAY-3: settle balance', () {
    Future<_FlakyEarningsDriversRepository> pumpEarningsWithOwedBalance(
      WidgetTester tester, {
      int owedCents = 50000,
    }) async {
      final drivers = _FlakyEarningsDriversRepository(
        jobs: fastFakeJobs(),
        actionDelay: const Duration(milliseconds: 10),
      )..overrideBalance = DriverBalance(owedCents: owedCents);
      await tester.pumpWidget(TheCraneApp(
        dependencies:
            testDependencies(drivers: drivers, authRole: UserRole.driver),
      ));
      await tester.pumpAndSettle();
      await signIn(tester);
      await tester.tap(find.byKey(const Key('earningsNavButton')));
      await tester.pumpAndSettle();
      return drivers;
    }

    testWidgets('the settle button is hidden when nothing is owed',
        (tester) async {
      await pumpEarningsWithOwedBalance(tester, owedCents: 0);

      expect(find.byKey(const Key('settleBalanceButton')), findsNothing);
    });

    testWidgets(
        'requesting a Nequi settlement shows the "check your app" '
        'confirmation and never touches the shown balance', (tester) async {
      final drivers = await pumpEarningsWithOwedBalance(tester, owedCents: 50000);

      await tester.tap(find.byKey(const Key('settleBalanceButton')));
      await tester.pumpAndSettle();

      // Prefilled with the full owed amount; Nequi is the default method.
      expect(
        tester.widget<TextField>(find.byKey(const Key('settleAmountField'))).controller!.text,
        '50000',
      );

      await tester.tap(find.byKey(const Key('settleSubmitButton')));
      await tester.pumpAndSettle();

      expect(drivers.lastSettleCall, (amountCop: 50000, method: SettlementPaymentMethod.nequi));
      expect(
        find.text('Solicitud enviada. Revisa tu app de Nequi para aprobar el pago.'),
        findsOneWidget,
      );
      // The balance itself never moves from a settlement request alone --
      // only a real Wompi webhook does that.
      expect(
        tester.widget<Text>(find.byKey(const Key('earningsOwedAmount'))).data,
        formatCop(50000),
      );
    });

    testWidgets('the submit button stays disabled for an amount over the owed balance',
        (tester) async {
      await pumpEarningsWithOwedBalance(tester, owedCents: 50000);

      await tester.tap(find.byKey(const Key('settleBalanceButton')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('settleAmountField')), '999999');
      await tester.pump();

      final submitButton =
          tester.widget<FilledButton>(find.byKey(const Key('settleSubmitButton')));
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('a 503 (no Wompi key configured) shows the "not available yet" message',
        (tester) async {
      final drivers = await pumpEarningsWithOwedBalance(tester, owedCents: 50000);
      drivers.rejectNextSettleAsUnavailable = true;

      await tester.tap(find.byKey(const Key('settleBalanceButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settleSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('La liquidación digital no está disponible todavía. Intenta más tarde.'),
        findsOneWidget,
      );
    });
  });
}
