import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../job/active_job_cubit.dart';
import 'offer_cubit.dart';

/// DRV-2 — incoming offer bottom sheet: pickup distance, route summary,
/// vehicle type, fare, commission preview and the TTL countdown.
///
/// Dismissal is driven exclusively by [OfferCubit] (accept, reject or
/// timeout) through the listener in `DriverHomeScreen`, so the sheet itself
/// is not drag- or barrier-dismissible.
class OfferSheet extends StatelessWidget {
  const OfferSheet({super.key});

  Future<void> _accept(BuildContext context) async {
    final activeJobCubit = context.read<ActiveJobCubit>();
    final job = await context.read<OfferCubit>().accept();
    if (job != null) activeJobCubit.start(job);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocBuilder<OfferCubit, ActiveOffer?>(
      builder: (context, active) {
        if (active == null) return const SizedBox.shrink();

        final offer = active.offer;
        final job = offer.job;
        final earnings = job.quotedPrice - offer.commissionAmount;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.offerTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.offerPickupDistance(formatKm(offer.pickupDistanceKm)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _RouteRow(
                  icon: Icons.trip_origin,
                  label: l10n.pickupFieldLabel,
                  value: job.pickupAddress,
                ),
                const SizedBox(height: 8),
                _RouteRow(
                  icon: Icons.place_outlined,
                  label: l10n.dropoffFieldLabel,
                  value: job.dropoffAddress,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(job.vehicleType.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(job.vehicleType.label(l10n)),
                    const Spacer(),
                    Text(l10n.distanceKm(formatKm(job.distanceKm))),
                  ],
                ),
                const Divider(height: 24),
                _AmountRow(
                  label: l10n.fareLabel,
                  value: formatCop(job.quotedPrice),
                ),
                _AmountRow(
                  label: l10n.offerCommissionLabel,
                  value: '- ${formatCop(offer.commissionAmount)}',
                ),
                _AmountRow(
                  label: l10n.offerEarningsLabel,
                  value: formatCop(earnings),
                  emphasized: true,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: active.remainingSeconds / offer.ttlSeconds,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.offerCountdown(active.remainingSeconds),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('acceptOfferButton'),
                  onPressed: () => _accept(context),
                  child: Text(l10n.acceptButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: context.read<OfferCubit>().reject,
                  child: Text(l10n.rejectButton),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
