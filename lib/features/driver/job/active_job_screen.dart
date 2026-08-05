import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/job.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../../shared/widgets/map_placeholder.dart';
import 'active_job_cubit.dart';

/// DRV-3 skeleton — active job: route summary, current status, and the
/// status-advance button cycling the JOB-3 machine.
///
/// TODO(DRV-3): map with route (FND-6), Google Maps navigation deep-link,
/// call-customer button, and driver cancel (returns job to matching).
class ActiveJobScreen extends StatelessWidget {
  const ActiveJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final job = context.watch<ActiveJobCubit>().state;
    final cubit = context.read<ActiveJobCubit>();

    if (job == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.activeJobTitle)),
        body: Center(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            child: Text(l10n.backToHomeButton),
          ),
        ),
      );
    }

    final next = job.status.nextDriverStatus;
    final done = job.status == JobStatus.completed;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activeJobTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 140, child: MapPlaceholder()),
              const SizedBox(height: 16),
              Center(
                child: Chip(
                  key: const Key('jobStatusChip'),
                  avatar: Icon(
                    done ? Icons.check_circle : Icons.local_shipping,
                    size: 18,
                  ),
                  label: Text(job.status.label(l10n)),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AddressLine(
                        icon: Icons.trip_origin,
                        label: l10n.pickupFieldLabel,
                        value: job.pickupAddress,
                      ),
                      const SizedBox(height: 12),
                      _AddressLine(
                        icon: Icons.place_outlined,
                        label: l10n.dropoffFieldLabel,
                        value: job.dropoffAddress,
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.fareLabel),
                          Text(
                            formatCop(job.quotedPrice),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (done) ...[
                Text(
                  l10n.jobDoneBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('backToHomeButton'),
                  onPressed: () {
                    cubit.clear();
                    context.pop();
                  },
                  child: Text(l10n.backToHomeButton),
                ),
              ] else if (next != null)
                FilledButton(
                  key: const Key('advanceStatusButton'),
                  onPressed: cubit.advance,
                  child: Text(next.advanceActionLabel(l10n)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
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
