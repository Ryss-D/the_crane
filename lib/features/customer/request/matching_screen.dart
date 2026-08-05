import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/job.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import 'request_bloc.dart';

/// CUS-3 skeleton — matching outcome states: searching, assigned driver
/// card, no-drivers with retry.
///
/// Job updates arrive through `JobsRepository.watchJob`;
/// TODO(TRK-4): that seam switches from fake/polling to WebSocket events.
class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key});

  void _leave(BuildContext context) {
    context.read<RequestBloc>().add(const RequestMatchingAbandoned());
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final job = context.select<RequestBloc, Job?>(
      (bloc) => bloc.state.activeJob,
    );

    final Widget body;
    if (job == null || job.status == JobStatus.noDrivers) {
      body = _NoDriversView(
        onRetry: () =>
            context.read<RequestBloc>().add(const RequestMatchingRetried()),
        onCancel: () => _leave(context),
      );
    } else if (job.status == JobStatus.requested ||
        job.status == JobStatus.matching) {
      body = _SearchingView(onCancel: () => _leave(context));
    } else {
      body = _AssignedView(job: job, onDone: () => _leave(context));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchingTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: body),
        ),
      ),
    );
  }
}

/// «Buscando tu grúa» searching animation.
class _SearchingView extends StatelessWidget {
  const _SearchingView({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SizedBox.square(
            dimension: 72,
            child: CircularProgressIndicator(strokeWidth: 6),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.matchingTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(l10n.matchingBody, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        OutlinedButton(onPressed: onCancel, child: Text(l10n.cancelButton)),
      ],
    );
  }
}

/// Assigned-driver card: name, plate, truck type, rating (photo TODO).
class _AssignedView extends StatelessWidget {
  const _AssignedView({required this.job, required this.onDone});

  final Job job;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final driver = job.driver;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.assignedTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(l10n.assignedBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (driver != null)
          Card(
            child: ListTile(
              // TODO(CUS-3): real driver photo once uploads exist.
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(driver.name),
              subtitle: Text(
                [
                  l10n.driverPlateLabel(driver.truckPlate),
                  if (driver.truckType != null) driver.truckType!.label(l10n),
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(driver.ratingAvg.toStringAsFixed(1)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          formatCop(job.quotedPrice),
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // TODO(CUS-4): live tracking (driver marker + status timeline)
        // replaces this button once TRK-4 lands.
        FilledButton(onPressed: onDone, child: Text(l10n.backToHomeButton)),
      ],
    );
  }
}

/// No-drivers state with retry (CUS-3).
class _NoDriversView extends StatelessWidget {
  const _NoDriversView({required this.onRetry, required this.onCancel});

  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.search_off, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          l10n.noDriversTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(l10n.noDriversBody, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(onPressed: onRetry, child: Text(l10n.retryButton)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onCancel, child: Text(l10n.cancelButton)),
      ],
    );
  }
}
