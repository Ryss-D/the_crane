import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import 'driver_balance_cubit.dart';

/// DRV-5 — the driver's owed commission balance plus recent settlements.
/// The app bar's list icon leads to DRV-6's services-per-period breakdown.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.earningsTitle),
        actions: [
          IconButton(
            key: const Key('servicesPeriodNavButton'),
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n.servicesPeriodTitle,
            onPressed: () => context.push(AppRoute.driverServicesPeriod),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DriverBalanceCubit, DriverBalanceState>(
          builder: (context, state) {
            final balance = state.balance;
            if (state.isLoading && balance == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed && balance == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.earningsLoadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<DriverBalanceCubit>().load(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            if (balance == null) return const SizedBox.shrink();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.earningsOwedLabel),
                        const SizedBox(height: 4),
                        Text(
                          formatCop(balance.owedCents),
                          key: const Key('earningsOwedAmount'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (balance.balanceCapCents != null) ...[
                          const SizedBox(height: 12),
                          Text(l10n.earningsCapLabel),
                          Text(formatCop(balance.balanceCapCents!)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.earningsSettlementsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (balance.recentSettlements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.earningsNoSettlementsBody),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final settlement in balance.recentSettlements)
                          ListTile(
                            key: Key('settlementRow_${settlement.id}'),
                            title: Text(formatCop(settlement.amountCents)),
                            subtitle: Text(
                              settlement.note == null
                                  ? formatHistoryDate(settlement.settledAt)
                                  : '${formatHistoryDate(settlement.settledAt)} · ${settlement.note}',
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
