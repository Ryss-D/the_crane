import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import 'services_period_cubit.dart';

/// DRV-6 — the driver's completed jobs grouped by day: a Today/Week/Month/
/// Custom-range selector, a totals summary, and a per-day bar-list (this
/// app has no charting package; a plain proportional-width bar per row
/// substitutes for one) that all update together off the same filtered set.
class ServicesPeriodScreen extends StatelessWidget {
  const ServicesPeriodScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context) async {
    final cubit = context.read<ServicesPeriodCubit>();
    final now = DateTime.now();
    final current = cubit.state;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: current.customStart != null && current.customEnd != null
          ? DateTimeRange(start: current.customStart!, end: current.customEnd!)
          : null,
    );
    if (picked != null) {
      cubit.setCustomRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.servicesPeriodTitle)),
      body: SafeArea(
        child: BlocBuilder<ServicesPeriodCubit, ServicesPeriodState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _FilterSelector(
                    state: state,
                    onPickCustomRange: () => _pickCustomRange(context),
                  ),
                ),
                Expanded(child: _PeriodBody(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterSelector extends StatelessWidget {
  const _FilterSelector({required this.state, required this.onPickCustomRange});

  final ServicesPeriodState state;
  final VoidCallback onPickCustomRange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ServicesPeriodFilter>(
          key: const Key('servicesPeriodFilterSelector'),
          segments: [
            ButtonSegment(
              value: ServicesPeriodFilter.today,
              label: Text(l10n.servicesPeriodFilterToday),
            ),
            ButtonSegment(
              value: ServicesPeriodFilter.week,
              label: Text(l10n.servicesPeriodFilterWeek),
            ),
            ButtonSegment(
              value: ServicesPeriodFilter.month,
              label: Text(l10n.servicesPeriodFilterMonth),
            ),
            ButtonSegment(
              value: ServicesPeriodFilter.custom,
              label: Text(l10n.servicesPeriodFilterCustom),
            ),
          ],
          selected: {state.filter},
          onSelectionChanged: (selection) {
            final picked = selection.first;
            if (picked == ServicesPeriodFilter.custom) {
              onPickCustomRange();
            } else {
              context.read<ServicesPeriodCubit>().setFilter(picked);
            }
          },
        ),
        if (state.filter == ServicesPeriodFilter.custom) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('servicesPeriodCustomRangeButton'),
            onPressed: onPickCustomRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              state.customStart != null && state.customEnd != null
                  ? '${formatDay(state.customStart!)} - ${formatDay(state.customEnd!)}'
                  : l10n.servicesPeriodPickRangeButton,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({required this.state});

  final ServicesPeriodState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              onPressed: () => context.read<ServicesPeriodCubit>().load(),
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      );
    }
    if (state.periods.isEmpty) {
      return Center(child: Text(l10n.servicesPeriodEmptyBody));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          key: const Key('servicesPeriodTotalsCard'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.servicesCountLabel(state.totalJobCount)),
                Text(
                  formatCop(state.totalFare),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${l10n.servicesCommissionLabel}: ${formatCop(state.totalCommission)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final summary in state.periods)
          _PeriodBarRow(summary: summary, maxFare: state.maxDayFare),
      ],
    );
  }
}

/// A day's row plus a proportional-width bar behind its fare — the
/// dependency-free "simple chart" substitute (DRV-6).
class _PeriodBarRow extends StatelessWidget {
  const _PeriodBarRow({required this.summary, required this.maxFare});

  final ServicesPeriodSummary summary;
  final int maxFare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fraction = maxFare > 0 ? summary.totalFare / maxFare : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        key: Key('servicesPeriodRow_${summary.day.toIso8601String()}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDay(summary.day)),
              Text(
                formatCop(summary.totalFare),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.servicesCountLabel(summary.jobCount)} · '
            '${l10n.servicesCommissionLabel}: ${formatCop(summary.totalCommission)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
