import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/driver_profile.dart';
import '../../../core/models/truck.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import 'fleet_cubit.dart';

/// FLT-3 — "Mi flota": every truck in the caller's fleet with its plate and
/// status at a glance (available / on job / unassigned / offline).
class FleetHomeScreen extends StatelessWidget {
  const FleetHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fleetHomeTitle)),
      body: SafeArea(
        child: BlocBuilder<FleetCubit, FleetState>(
          builder: (context, state) {
            final fleet = state.fleet;
            if (state.isLoading && fleet == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed && fleet == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.fleetLoadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<FleetCubit>().load(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            if (fleet == null) return const SizedBox.shrink();
            if (fleet.trucks.isEmpty) {
              return Center(child: Text(l10n.fleetEmptyBody));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: fleet.trucks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _TruckRow(truck: fleet.trucks[index]),
            );
          },
        ),
      ),
    );
  }
}

class _TruckRow extends StatelessWidget {
  const _TruckRow({required this.truck});

  final Truck truck;

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (truck.driverId == null) return scheme.outline;
    return switch (truck.driverStatus) {
      DriverStatus.available => Colors.green,
      DriverStatus.onJob => Colors.orange,
      DriverStatus.offline || null => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      key: Key('fleetTruckRow_${truck.id}'),
      leading: Icon(Icons.local_shipping_outlined, color: _statusColor(context)),
      title: Text(truck.plate),
      subtitle: Text(
        truck.driverName == null
            ? truck.fleetStatusLabel(l10n)
            : '${truck.driverName} · ${truck.fleetStatusLabel(l10n)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoute.fleetTruckDetail(truck.id)),
    );
  }
}
