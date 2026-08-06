import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/fleet_repository.dart';
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

/// FLT-3/FLT-4 — truck detail: plate, type, capacity, the current driver's
/// name/status (if any is assigned), and a detach action. Reads live from
/// [FleetCubit]'s state rather than fetching its own copy, so an attach
/// done elsewhere (`AddTruckScreen`) is reflected here immediately.
class FleetTruckDetailScreen extends StatefulWidget {
  const FleetTruckDetailScreen({super.key, required this.truckId});

  final String truckId;

  @override
  State<FleetTruckDetailScreen> createState() =>
      _FleetTruckDetailScreenState();
}

class _FleetTruckDetailScreenState extends State<FleetTruckDetailScreen> {
  bool _detaching = false;
  bool _detachFailed = false;

  Future<void> _confirmDetach(Truck truck) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.detachTruckConfirmTitle),
        content: Text(l10n.detachTruckConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const Key('confirmDetachButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.detachTruckButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _detaching = true;
      _detachFailed = false;
    });
    try {
      await context.read<FleetRepository>().detachTruck(truck.id);
      if (!mounted) return;
      await context.read<FleetCubit>().refresh();
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _detaching = false;
          _detachFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fleet = context.watch<FleetCubit>().state.fleet;
    final truck = _findTruck(fleet, widget.truckId);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: l10n.plateFieldLabel,
                        value: truck.plate,
                      ),
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
                        value:
                            truck.driverName ?? l10n.fleetTruckStatusUnassigned,
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
              const SizedBox(height: 24),
              if (_detachFailed) ...[
                Text(
                  l10n.detachTruckError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                key: const Key('detachTruckButton'),
                onPressed:
                    _detaching ? null : () => unawaited(_confirmDetach(truck)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: _detaching
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.detachTruckButton),
              ),
            ],
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
