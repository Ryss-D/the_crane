import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/models/driver_balance.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../../shared/rating/rating_dialog.dart';
import '../../shared/widgets/map_placeholder.dart';
import 'active_job_cubit.dart';

/// Statuses a driver may still bail out of (mirrors `DRIVER_CANCELLABLE` in
/// `backend/app/services/jobs.py`) — once `loading` starts, the driver is
/// committed and the cancel button disappears.
const _driverCancellableStatuses = {
  JobStatus.assigned,
  JobStatus.enRoutePickup,
  JobStatus.arrivedPickup,
};

/// DRV-3 — the job's current leg: pickup while still on the way to/at the
/// pickup point, dropoff once loading (and everything after) starts. Backs
/// the "navigate" deep-link button below.
LatLng _navigationTarget(Job job) => switch (job.status) {
      JobStatus.loading ||
      JobStatus.inTransit ||
      JobStatus.delivered ||
      JobStatus.completed =>
        job.dropoff,
      _ => job.pickup,
    };

/// DRV-3 skeleton — active job: route summary, current status, and the
/// status-advance button cycling the JOB-3 machine.
///
/// TODO(DRV-3/FND-6): map with route stays blocked on Google Maps. The
/// navigation deep-link, and driver cancel below are built; a call-customer
/// button is NOT -- `JobRead`/`Job` carry no customer phone number anywhere
/// (checked `backend/app/schemas/job.py`'s `JobRead`/`JobDriverInfo`: only
/// the *driver's* phone is ever exposed, to the customer, via
/// `JobDriverSummary` -- there is no symmetric "customer summary" on the
/// job at all). That's a real gap, not a wiring gap: without a backend
/// change, there is no legitimate customer phone number for this button to
/// call.
class ActiveJobScreen extends StatelessWidget {
  const ActiveJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActiveJobCubit, ActiveJobState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      },
      child: const _ActiveJobView(),
    );
  }
}

class _ActiveJobView extends StatelessWidget {
  const _ActiveJobView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final job = context.watch<ActiveJobCubit>().state.job;
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
        child: SingleChildScrollView(
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
              if (!done) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('navigateButton'),
                  onPressed: () => _openNavigation(_navigationTarget(job)),
                  icon: const Icon(Icons.navigation_outlined),
                  label: Text(l10n.navigateButton),
                ),
              ],
              const SizedBox(height: 32),
              if (done) ...[
                Text(
                  l10n.jobDoneBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                // DRV-4 AC: shows commission accrued for this job and the
                // new running balance once the customer's cash-payment
                // confirmation (CUS-5) completes it.
                _JobCommissionSection(job: job),
                const SizedBox(height: 12),
                // RAT-2: skippable — tapping "back to home" directly, below,
                // leaves the trip unrated.
                OutlinedButton(
                  key: const Key('rateTripButton'),
                  onPressed: () => showRatingDialog(context, jobId: job.id),
                  child: Text(l10n.rateTripButton),
                ),
                const SizedBox(height: 8),
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
                )
              else if (job.status == JobStatus.delivered)
                // CUS-5/DRV-4: completion is the customer's cash-payment
                // confirmation (`confirm-delivery`) — the driver has no
                // action here; `ActiveJobCubit`'s `watchJob` subscription
                // flips this screen to the `done` state above live, once
                // the customer confirms.
                Text(
                  l10n.waitingCashConfirmationBody,
                  key: const Key('waitingCashConfirmationText'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              if (!done && _driverCancellableStatuses.contains(job.status)) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('cancelJobButton'),
                  onPressed: () => _confirmCancel(context, cubit, l10n),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l10n.cancelJobButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// DRV-3 — opens Google Maps (app if installed, web otherwise) turn-by-turn
/// navigation to [target] via the cross-platform web intent
/// (`https://www.google.com/maps/dir/?api=1&destination=...`) rather than a
/// native Maps SDK — no API key/native setup needed, and it works the same
/// on Android/iOS/web.
Future<void> _openNavigation(LatLng target) {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${target.lat},${target.lng}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// DRV-3 — confirm-then-cancel, mirrors `FleetTruckDetailScreen`'s
/// `_confirmDetach` dialog pattern.
Future<void> _confirmCancel(
  BuildContext context,
  ActiveJobCubit cubit,
  AppLocalizations l10n,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cancelJobConfirmTitle),
      content: Text(l10n.cancelJobConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('confirmCancelJobButton'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cancelJobButton),
        ),
      ],
    ),
  );
  if (confirmed == true) await cubit.cancel();
}

/// DRV-4 — once a job is `completed`, shows the commission earned on it
/// plus the driver's fresh running balance (DRV-5's `DriversRepository
/// .balance`).
class _JobCommissionSection extends StatefulWidget {
  const _JobCommissionSection({required this.job});

  final Job job;

  @override
  State<_JobCommissionSection> createState() => _JobCommissionSectionState();
}

class _JobCommissionSectionState extends State<_JobCommissionSection> {
  late final Future<DriverBalance> _future =
      context.read<DriversRepository>().balance();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fare = widget.job.finalPrice ?? widget.job.quotedPrice;
    final commission =
        widget.job.driverCommission ?? (fare * 0.15 / 100).round() * 100;
    return FutureBuilder<DriverBalance>(
      future: _future,
      builder: (context, snapshot) {
        final balance = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.jobCommissionLabel),
                Text(
                  formatCop(commission),
                  key: const Key('jobCommissionAmount'),
                ),
              ],
            ),
            if (balance != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.runningBalanceLabel),
                  Text(
                    formatCop(balance.owedCents),
                    key: const Key('runningBalanceAmount'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        );
      },
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
