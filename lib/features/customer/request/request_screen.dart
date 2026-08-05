import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/job.dart';
import '../../../core/models/quote.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../../shared/widgets/map_placeholder.dart';
import 'request_bloc.dart';
import 'request_state.dart';

/// CUS-1/2 — request a tow: pickup/dropoff, vehicle type, quote, confirm.
///
/// TODO(FND-6): the text fields become a map with pin-drag + Places search
/// once Google Maps is wired; [MapPlaceholder] marks the spot.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<RequestBloc>();

    return BlocListener<RequestBloc, RequestState>(
      // Job created → move to the CUS-3 matching screen.
      listenWhen: (previous, current) =>
          previous.activeJob == null && current.activeJob != null,
      listener: (context, state) => context.push(AppRoute.customerMatching),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.customerHomeTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 150, child: MapPlaceholder()),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('pickupField'),
                  onChanged: (value) => bloc.add(RequestPickupChanged(value)),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.pickupFieldLabel,
                    hintText: l10n.pickupFieldHint,
                    prefixIcon: const Icon(Icons.trip_origin),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('dropoffField'),
                  onChanged: (value) => bloc.add(RequestDropoffChanged(value)),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.dropoffFieldLabel,
                    hintText: l10n.dropoffFieldHint,
                    prefixIcon: const Icon(Icons.place_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.vehicleTypeLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                BlocBuilder<RequestBloc, RequestState>(
                  buildWhen: (previous, current) =>
                      previous.vehicleType != current.vehicleType,
                  builder: (context, state) => SegmentedButton<VehicleType>(
                    segments: [
                      for (final type in VehicleType.values)
                        ButtonSegment(
                          value: type,
                          icon: Icon(type.icon),
                          label: Text(type.label(l10n)),
                        ),
                    ],
                    selected: {state.vehicleType},
                    onSelectionChanged: (selection) =>
                        bloc.add(RequestVehicleTypeChanged(selection.first)),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<RequestBloc, RequestState>(
                  builder: (context, state) => _QuoteCard(
                    quote: state.quote,
                    isQuoting: state.isQuoting,
                    quoteFailed: state.quoteFailed,
                    onRetry: () => bloc.add(const RequestQuoteRefreshed()),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<RequestBloc, RequestState>(
                  builder: (context, state) => FilledButton(
                    key: const Key('confirmRequestButton'),
                    onPressed: state.canConfirm
                        ? () => bloc.add(const RequestConfirmed())
                        : null,
                    child: state.isCreatingJob
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.confirmRequestButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CUS-2 quote card: COP price, ETA and distance, with loading/error states.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.isQuoting,
    required this.quoteFailed,
    required this.onRetry,
  });

  final Quote? quote;
  final bool isQuoting;
  final bool quoteFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final quote = this.quote;

    final Widget child;
    if (isQuoting) {
      child = const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (quoteFailed) {
      child = Column(
        children: [
          Text(l10n.quoteError, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l10n.retryButton)),
        ],
      );
    } else if (quote == null) {
      child = Text(
        l10n.quotePrompt,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.outline),
      );
    } else {
      child = Column(
        children: [
          Text(
            formatCop(quote.price),
            key: const Key('quotePrice'),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 4),
              Text(l10n.quoteEtaMinutes(quote.etaMinutes)),
              const SizedBox(width: 16),
              const Icon(Icons.route, size: 16),
              const SizedBox(width: 4),
              Text(l10n.distanceKm(formatKm(quote.distanceKm))),
            ],
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: child,
        ),
      ),
    );
  }
}
