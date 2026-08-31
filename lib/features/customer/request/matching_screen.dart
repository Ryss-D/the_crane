import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/directions_repository.dart';
import '../../../core/config/env.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../../shared/rating/rating_dialog.dart';
import '../../shared/widgets/crane_map.dart';
import 'request_bloc.dart';
import 'request_state.dart';

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
        // CUS-4 added enough content to `_AssignedView` (timeline, call/
        // share buttons) that it can now overflow shorter screens — scroll
        // instead of a bare `Center` so nothing clips.
        child: SingleChildScrollView(
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
      mainAxisSize: MainAxisSize.min,
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
      mainAxisSize: MainAxisSize.min,
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
          formatCop(job.finalPrice ?? job.quotedPrice),
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // FND-6: live driver marker + route, once a real backend socket
        // relays `driver_location` pushes (null/no marker under fakes).
        SizedBox(height: 140, child: _AssignedJobMap(job: job)),
        const SizedBox(height: 16),
        // CUS-4: happy-path status timeline.
        _StatusTimeline(status: job.status),
        const SizedBox(height: 16),
        if (driver?.phone != null || job.shareToken != null)
          Row(
            children: [
              if (driver?.phone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('callDriverButton'),
                    onPressed: () => _callDriver(driver!.phone!),
                    icon: const Icon(Icons.call),
                    label: Text(l10n.callDriverButton),
                  ),
                ),
              if (driver?.phone != null && job.shareToken != null)
                const SizedBox(width: 8),
              if (job.shareToken != null)
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('shareTripButton'),
                    onPressed: () => _shareTrip(context, job.shareToken!),
                    icon: const Icon(Icons.ios_share),
                    label: Text(l10n.shareTripButton),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        if (job.status == JobStatus.delivered) ...[
          // CUS-5: only the customer can complete a delivered job (cash
          // confirmation writes the driver's commission ledger entry
          // server-side) — the driver has no equivalent button.
          Text(l10n.cashPaymentPendingBody, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          // PAY-4: launches the Wompi checkout redirect the instant one
          // appears on the active job — `asyncPaymentUrl` is only ever
          // non-null on the exact confirmDelivery response that just
          // started a PSE/card checkout (see `JobRead`'s doc comment), so
          // this fires at most once per digital confirmation, never on an
          // unrelated rebuild.
          BlocListener<RequestBloc, RequestState>(
            listenWhen: (previous, current) =>
                current.activeJob?.asyncPaymentUrl != null &&
                previous.activeJob?.asyncPaymentUrl != current.activeJob?.asyncPaymentUrl,
            listener: (context, state) {
              final url = state.activeJob?.asyncPaymentUrl;
              if (url != null) unawaited(launchUrl(Uri.parse(url)));
            },
            child: BlocBuilder<RequestBloc, RequestState>(
              buildWhen: (previous, current) =>
                  previous.isConfirmingDelivery != current.isConfirmingDelivery ||
                  previous.confirmDeliveryFailed != current.confirmDeliveryFailed,
              builder: (context, state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.confirmDeliveryFailed) ...[
                    Text(
                      // PAY-4: a typed rejection here today only ever means
                      // "digital fares aren't enabled" (the 422 case) — the
                      // backend's own detail string is in English and not
                      // meant for direct display, so this maps to the
                      // localized equivalent rather than showing it raw.
                      state.confirmDeliveryErrorMessage != null
                          ? l10n.digitalPaymentNotAvailableError
                          : l10n.cashPaymentConfirmError,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    key: const Key('confirmCashPaymentButton'),
                    onPressed: state.isConfirmingDelivery
                        ? null
                        : () => context
                            .read<RequestBloc>()
                            .add(const RequestDeliveryConfirmed()),
                    child: state.isConfirmingDelivery
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.cashConfirmButton),
                  ),
                  const SizedBox(height: 8),
                  // PAY-4: no public endpoint tells the app whether
                  // `payments.digital_fares_enabled` is on server-side (see
                  // the doc note) -- shown unconditionally, a disabled flag
                  // surfaces as the 422 handled above rather than being
                  // predicted ahead of time.
                  OutlinedButton(
                    key: const Key('payDigitallyButton'),
                    onPressed: state.isConfirmingDelivery
                        ? null
                        : () async {
                            final method = await _showDigitalPaymentDialog(context, l10n);
                            if (method == null || !context.mounted) return;
                            context
                                .read<RequestBloc>()
                                .add(RequestDeliveryConfirmed(paymentMethod: method));
                          },
                    child: Text(l10n.payDigitallyButton),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (job.status == JobStatus.completed) ...[
          // RAT-2: skippable — tapping "back to home" directly leaves the
          // trip unrated.
          OutlinedButton(
            key: const Key('rateTripButton'),
            onPressed: () => showRatingDialog(context, jobId: job.id),
            child: Text(l10n.rateTripButton),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(onPressed: onDone, child: Text(l10n.backToHomeButton)),
      ],
    );
  }

  Future<void> _callDriver(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  Future<void> _shareTrip(BuildContext context, String shareToken) async {
    final l10n = AppLocalizations.of(context)!;
    final url = '${Env.webBaseUrl}/t/$shareToken';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.shareTripLinkCopied)),
    );
  }
}

/// PAY-4 — lets the customer pick a digital payment method before confirming
/// delivery non-cash. Returns the chosen wire value ("nequi"/"pse"/"card")
/// or null if dismissed without choosing.
Future<String?> _showDigitalPaymentDialog(BuildContext context, AppLocalizations l10n) {
  var selected = 'nequi';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(l10n.digitalPaymentDialogTitle),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => setState(() => selected = value!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                key: const Key('paymentMethodNequiOption'),
                value: 'nequi',
                title: Text(l10n.paymentMethodNequi),
                subtitle: Text(l10n.paymentMethodNequiHint),
              ),
              RadioListTile<String>(
                key: const Key('paymentMethodPseOption'),
                value: 'pse',
                title: Text(l10n.paymentMethodPse),
                subtitle: Text(l10n.paymentMethodRedirectHint),
              ),
              RadioListTile<String>(
                key: const Key('paymentMethodCardOption'),
                value: 'card',
                title: Text(l10n.paymentMethodCard),
                subtitle: Text(l10n.paymentMethodRedirectHint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('digitalPaymentDialogConfirmButton'),
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(l10n.digitalPaymentConfirmButton),
          ),
        ],
      ),
    ),
  );
}

/// FND-6/CUS-4 — pickup/dropoff pins, a route polyline, and (once a real
/// backend socket relays one) the assigned driver's live position. Same
/// "fetch the route once per job id, not on every rebuild" reasoning as
/// `ActiveJobScreen`'s `_ActiveJobMap` — this screen rebuilds on every
/// driver-location tick too.
class _AssignedJobMap extends StatefulWidget {
  const _AssignedJobMap({required this.job});

  final Job job;

  @override
  State<_AssignedJobMap> createState() => _AssignedJobMapState();
}

class _AssignedJobMapState extends State<_AssignedJobMap> {
  String? _fetchedForJobId;
  List<LatLng>? _routePoints;

  @override
  void initState() {
    super.initState();
    _maybeFetchRoute();
  }

  @override
  void didUpdateWidget(covariant _AssignedJobMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFetchRoute();
  }

  void _maybeFetchRoute() {
    if (_fetchedForJobId == widget.job.id) return;
    _fetchedForJobId = widget.job.id;
    unawaited(_fetch(widget.job.id));
  }

  Future<void> _fetch(String jobId) async {
    try {
      final points = await context.read<DirectionsRepository>().route(
            origin: widget.job.pickup,
            destination: widget.job.dropoff,
          );
      if (!mounted || _fetchedForJobId != jobId) return;
      setState(() => _routePoints = points);
    } catch (_) {
      // Best-effort -- the map still shows pins without a line.
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverPosition = context.select<RequestBloc, LatLng?>(
      (bloc) => bloc.state.driverPosition,
    );
    return CraneMap(
      markers: [
        CraneMapMarker(
          id: 'pickup',
          position: widget.job.pickup,
          role: CraneMapMarkerRole.pickup,
        ),
        CraneMapMarker(
          id: 'dropoff',
          position: widget.job.dropoff,
          role: CraneMapMarkerRole.dropoff,
        ),
        if (driverPosition != null)
          CraneMapMarker(
            id: 'driver',
            position: driverPosition,
            role: CraneMapMarkerRole.driver,
          ),
      ],
      routePoints: _fetchedForJobId == widget.job.id ? _routePoints : null,
    );
  }
}

/// CUS-4 happy-path status timeline. `cancelled`/`no_drivers` are
/// terminal-failure statuses, not steps in this sequence — they render as a
/// banner instead (mirrors `web-client`'s `StatusTimeline.tsx`).
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final JobStatus status;

  static const _steps = [
    JobStatus.assigned,
    JobStatus.enRoutePickup,
    JobStatus.arrivedPickup,
    JobStatus.loading,
    JobStatus.inTransit,
    JobStatus.delivered,
    JobStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final failed =
        status == JobStatus.cancelled || status == JobStatus.noDrivers;

    if (failed) {
      return Container(
        key: const Key('statusTimelineFailureBanner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.label(l10n),
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = _steps.indexOf(status);
    return Column(
      key: const Key('statusTimeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          _StatusTimelineStep(
            status: _steps[i],
            label: _steps[i].label(l10n),
            done: currentIndex >= 0 && i < currentIndex,
            current: i == currentIndex,
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }
}

class _StatusTimelineStep extends StatelessWidget {
  const _StatusTimelineStep({
    required this.status,
    required this.label,
    required this.done,
    required this.current,
    required this.isLast,
  });

  final JobStatus status;
  final String label;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = current || done
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final icon = done
        ? Icons.check_circle
        : current
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, key: Key('statusStepIcon_${status.wire}'), size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            key: Key('statusStepLabel_${status.wire}'),
            style: (current
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : theme.textTheme.bodyMedium)
                ?.copyWith(color: current || done ? null : theme.colorScheme.outline),
          ),
        ],
      ),
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
      mainAxisSize: MainAxisSize.min,
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
