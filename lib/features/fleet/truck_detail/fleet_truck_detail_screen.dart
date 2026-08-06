import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/fleet.dart';
import '../../../core/models/truck.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../home/fleet_cubit.dart';

Truck? _findTruck(Fleet? fleet, String truckId) {
  if (fleet == null) return null;
  for (final truck in fleet.trucks) {
    if (truck.id == truckId) return truck;
  }
  return null;
}

/// FLT-3 — truck detail: plate, type, capacity, and the current driver's
/// name/status (if any is assigned). Reads live from [FleetCubit]'s state
/// rather than fetching its own copy, so FLT-4's attach/detach actions
/// (which refresh the cubit) are reflected here immediately.
class FleetTruckDetailScreen extends StatelessWidget {
  const FleetTruckDetailScreen({super.key, required this.truckId});

  final String truckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fleet = context.watch<FleetCubit>().state.fleet;
    final truck = _findTruck(fleet, truckId);

    if (truck == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.fleetTruckDetailTitle)),
        body: Center(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            child: Text(l10n.backToHomeButton),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fleetTruckDetailTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: l10n.plateFieldLabel, value: truck.plate),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: l10n.truckTypeFieldLabel,
                    value: truck.type.label(l10n),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: l10n.capacityFieldLabel,
                    value: truck.capacity.label(l10n),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: l10n.fleetTruckDriverLabel,
                    value: truck.driverName ?? l10n.fleetTruckStatusUnassigned,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: l10n.fleetTruckStatusLabel,
                    value: truck.fleetStatusLabel(l10n),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
