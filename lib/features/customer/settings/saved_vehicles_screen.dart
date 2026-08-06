import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/saved_vehicle.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import 'saved_vehicle_form_dialog.dart';
import 'saved_vehicles_cubit.dart';

/// CUS-6 — list/add/edit/delete a customer's saved vehicles.
class SavedVehiclesScreen extends StatelessWidget {
  const SavedVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedVehiclesTitle)),
      body: SafeArea(
        child: BlocBuilder<SavedVehiclesCubit, SavedVehiclesState>(
          builder: (context, state) {
            if (state.isLoading && state.vehicles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed && state.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.loadVehiclesError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<SavedVehiclesCubit>().load(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            if (state.vehicles.isEmpty) {
              return Center(child: Text(l10n.noSavedVehiclesBody));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.vehicles.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _VehicleRow(vehicle: state.vehicles[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addVehicleButton'),
        tooltip: l10n.addVehicleButton,
        onPressed: () => showSavedVehicleFormDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final SavedVehicle vehicle;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteVehicleConfirmTitle),
        content: Text(l10n.deleteVehicleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SavedVehiclesCubit>().delete(vehicle.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitleParts = [
      if (vehicle.make != null || vehicle.model != null)
        [vehicle.make, vehicle.model].whereType<String>().join(' '),
      vehicle.plate,
    ].where((part) => part.isNotEmpty).join(' · ');
    return ListTile(
      key: Key('savedVehicleRow_${vehicle.id}'),
      leading: Icon(vehicle.type.icon),
      title: Text(vehicle.type.label(l10n)),
      subtitle: Text(subtitleParts),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('editVehicleButton_${vehicle.id}'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showSavedVehicleFormDialog(context, existing: vehicle),
          ),
          IconButton(
            key: Key('deleteVehicleButton_${vehicle.id}'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }
}
