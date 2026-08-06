import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import 'services_period_cubit.dart';

/// DRV-6 — the driver's completed jobs grouped by day: count and
/// commission/earnings per day.
class ServicesPeriodScreen extends StatelessWidget {
  const ServicesPeriodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.servicesPeriodTitle)),
      body: SafeArea(
        child: BlocBuilder<ServicesPeriodCubit, ServicesPeriodState>(
          builder: (context, state) {
            if (state.isLoading && state.periods.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed && state.periods.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.servicesPeriodLoadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<ServicesPeriodCubit>().load(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            if (state.periods.isEmpty) {
              return Center(child: Text(l10n.servicesPeriodEmptyBody));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.periods.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _PeriodRow(summary: state.periods[index]),
            );
          },
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.summary});

  final ServicesPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListTile(
      key: Key('servicesPeriodRow_${summary.day.toIso8601String()}'),
      title: Text(formatDay(summary.day)),
      subtitle: Text(l10n.servicesCountLabel(summary.jobCount)),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Tooltip(
            message: l10n.servicesEarningsLabel,
            child: Text(
              formatCop(summary.totalFare),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${l10n.servicesCommissionLabel}: ${formatCop(summary.totalCommission)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
