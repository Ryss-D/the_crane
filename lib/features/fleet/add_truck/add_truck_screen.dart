import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/fleet_repository.dart';
import '../../../core/models/truck.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../home/fleet_cubit.dart';

/// FLT-4 (scoped) — "agregar camión": a fleet owner looks up a truck by
/// plate and attaches it if it's unclaimed. Linking a truck this way
/// exercises the exact resource FLT-1's backend gates on (`fleet_id is
/// null`) -- there is no consent/invite step yet (see the FLT-4 doc entry
/// for why: no backend invite mechanism exists), so a truck already
/// claimed by another fleet is shown clearly and cannot be attached here.
class AddTruckScreen extends StatefulWidget {
  const AddTruckScreen({super.key});

  @override
  State<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends State<AddTruckScreen> {
  final _plateController = TextEditingController();
  bool _searching = false;
  bool _notFound = false;
  bool _searchFailed = false;
  Truck? _foundTruck;
  bool _attaching = false;
  bool _attachFailed = false;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _notFound = false;
      _searchFailed = false;
      _foundTruck = null;
      _attachFailed = false;
    });
    try {
      final truck = await context.read<FleetRepository>().findTruckByPlate(plate);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _foundTruck = truck;
      });
    } on TruckNotFoundException {
      if (mounted) setState(() { _searching = false; _notFound = true; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; _searchFailed = true; });
    }
  }

  Future<void> _attach() async {
    final truck = _foundTruck;
    if (truck == null || _attaching) return;
    setState(() {
      _attaching = true;
      _attachFailed = false;
    });
    try {
      await context.read<FleetRepository>().attachTruck(truck.id);
      if (!mounted) return;
      await context.read<FleetCubit>().refresh();
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (mounted) setState(() { _attaching = false; _attachFailed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final truck = _foundTruck;
    final alreadyClaimed = truck != null && truck.fleetId != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addTruckTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addTruckIntro),
              const SizedBox(height: 24),
              TextField(
                key: const Key('addTruckPlateField'),
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.plateFieldLabel,
                  hintText: l10n.plateFieldHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('addTruckSearchButton'),
                onPressed: _plateController.text.trim().isEmpty || _searching
                    ? null
                    : _search,
                child: _searching
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.addTruckSearchButton),
              ),
              if (_notFound) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.addTruckNotFoundBody,
                  key: const Key('addTruckNotFoundText'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (_searchFailed) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.addTruckSearchError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (truck != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(truck.plate, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${truck.type.label(l10n)} · ${truck.capacity.label(l10n)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (alreadyClaimed)
                  Text(
                    l10n.addTruckAlreadyClaimedBody,
                    key: const Key('addTruckAlreadyClaimedText'),
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else ...[
                  if (_attachFailed) ...[
                    Text(
                      l10n.addTruckAttachError,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    key: const Key('addTruckAttachButton'),
                    onPressed: _attaching ? null : _attach,
                    child: _attaching
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.addTruckAttachButton),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
