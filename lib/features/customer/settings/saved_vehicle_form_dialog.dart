import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/job.dart';
import '../../../core/models/saved_vehicle.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import 'saved_vehicles_cubit.dart';

/// CUS-6 — add/edit form for a saved vehicle. Pass [existing] to edit it in
/// place; omit it to create a new one. Returns true once the save succeeds,
/// false if the dialog was cancelled or dismissed without saving.
Future<bool> showSavedVehicleFormDialog(
  BuildContext context, {
  SavedVehicle? existing,
}) {
  final cubit = context.read<SavedVehiclesCubit>();
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => BlocProvider.value(
      // The dialog attaches to the root navigator, outside whatever shell
      // provided the cubit — re-provide it explicitly (same pattern as
      // `showRatingDialog`).
      value: cubit,
      child: _SavedVehicleFormDialog(existing: existing),
    ),
  ).then((value) => value ?? false);
}

class _SavedVehicleFormDialog extends StatefulWidget {
  const _SavedVehicleFormDialog({this.existing});

  final SavedVehicle? existing;

  @override
  State<_SavedVehicleFormDialog> createState() =>
      _SavedVehicleFormDialogState();
}

class _SavedVehicleFormDialogState extends State<_SavedVehicleFormDialog> {
  late final _plateController =
      TextEditingController(text: widget.existing?.plate ?? '');
  late final _makeController =
      TextEditingController(text: widget.existing?.make ?? '');
  late final _modelController =
      TextEditingController(text: widget.existing?.model ?? '');
  late VehicleType _type = widget.existing?.type ?? VehicleType.car;
  bool _failed = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _failed = false);
    final cubit = context.read<SavedVehiclesCubit>();
    final plate = _plateController.text.trim();
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final ok = _isEditing
        ? await cubit.update(
            widget.existing!.id,
            type: _type,
            make: make.isEmpty ? null : make,
            model: model.isEmpty ? null : model,
            plate: plate,
          )
        : await cubit.create(
            type: _type,
            make: make.isEmpty ? null : make,
            model: model.isEmpty ? null : model,
            plate: plate,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SavedVehiclesCubit, SavedVehiclesState>(
      buildWhen: (previous, current) => previous.isSaving != current.isSaving,
      builder: (context, state) => AlertDialog(
        title: Text(_isEditing ? l10n.editVehicleTitle : l10n.addVehicleButton),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<VehicleType>(
                key: const Key('vehicleFormTypeSelector'),
                segments: [
                  for (final type in VehicleType.values)
                    ButtonSegment(
                      value: type,
                      icon: Icon(type.icon),
                      label: Text(type.label(l10n)),
                    ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('vehicleFormPlateField'),
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.plateFieldLabel,
                  hintText: l10n.plateFieldHint,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('vehicleFormMakeField'),
                controller: _makeController,
                decoration: InputDecoration(labelText: l10n.vehicleMakeFieldLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('vehicleFormModelField'),
                controller: _modelController,
                decoration: InputDecoration(labelText: l10n.vehicleModelFieldLabel),
              ),
              if (_failed) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.vehicleSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.isSaving
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const Key('vehicleFormSaveButton'),
            onPressed: state.isSaving || _plateController.text.trim().isEmpty
                ? null
                : _save,
            child: state.isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.vehicleSaveButton),
          ),
        ],
      ),
    );
  }
}
