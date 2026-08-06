import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import 'fleet_balance_cubit.dart';

/// FLT-5 — fleet earnings: the consolidated owed balance across every
/// driver in the fleet, plus the per-driver breakdown it's built from
/// (mirrors DRV-5's `EarningsScreen` for an individual driver).
class FleetBalanceScreen extends StatelessWidget {
  const FleetBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fleetBalanceTitle)),
      body: SafeArea(
        child: BlocBuilder<FleetBalanceCubit, FleetBalanceState>(
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
                    Text(l10n.fleetBalanceLoadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<FleetBalanceCubit>().load(),
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
                        Text(l10n.fleetBalanceOwedLabel),
                        const SizedBox(height: 4),
                        Text(
                          formatCop(balance.owedBalance),
                          key: const Key('fleetBalanceOwedAmount'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.fleetBalanceMembersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (balance.members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.fleetBalanceNoMembersBody),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final member in balance.members)
                          ListTile(
                            key: Key('fleetMemberBalanceRow_${member.driverId}'),
                            title: Text(member.name ?? member.driverId),
                            trailing: Text(formatCop(member.owedBalance)),
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
