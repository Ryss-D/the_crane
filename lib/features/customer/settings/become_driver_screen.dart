import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/models/truck.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_cubit.dart';
import '../../shared/labels.dart';

/// AUTH-5 — a signed-in customer becomes a driver: truck plate/type/
/// capacity, plus optional license/truck-photo URLs (document upload to
/// object storage is out of scope — see `DriverRegisterRequest` in
/// `backend/app/schemas/driver.py`).
///
/// FLT-4 adds a second, mutually exclusive path: redeeming a fleet owner's
/// invite instead of registering your own truck. The real product shape for
/// this would be a deep link carrying the invite token (tap a link the
/// fleet owner sent over WhatsApp/SMS, land here pre-filled); this app has
/// no deep-link handling wired yet (go_router's own URL routing only covers
/// in-app navigation), so as a pragmatic stand-in this screen instead lets
/// the driver paste/type the invite token by hand. Swap this field for a
/// deep-link-populated one once that plumbing exists.
///
/// On success the backend has already flipped the caller's role to
/// `driver` server-side; [AuthCubit.refreshUser] re-syncs the local profile
/// so `routerRedirect` (`lib/app/router.dart`) lands on the driver shell on
/// its next redirect evaluation — no explicit navigation is done here.
class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

/// Which shape of `registerDriver` this screen is currently filling out.
enum _RegistrationMode { ownTruck, invite }

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _plateController = TextEditingController();
  final _inviteTokenController = TextEditingController();
  final _licenseUrlController = TextEditingController();
  final _truckPhotoUrlController = TextEditingController();
  TruckType _truckType = TruckType.flatbed;
  TruckCapacity _capacity = TruckCapacity.both;
  _RegistrationMode _mode = _RegistrationMode.ownTruck;
  bool _submitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _plateController.dispose();
    _inviteTokenController.dispose();
    _licenseUrlController.dispose();
    _truckPhotoUrlController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      (_mode == _RegistrationMode.invite
          ? _inviteTokenController.text.trim().isNotEmpty
          : _plateController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      final license = _licenseUrlController.text.trim();
      final truckPhoto = _truckPhotoUrlController.text.trim();
      await context.read<DriversRepository>().registerDriver(
            plate: _mode == _RegistrationMode.ownTruck
                ? _plateController.text.trim()
                : null,
            truckType: _mode == _RegistrationMode.ownTruck ? _truckType : null,
            capacity: _mode == _RegistrationMode.ownTruck ? _capacity : null,
            inviteToken: _mode == _RegistrationMode.invite
                ? _inviteTokenController.text.trim()
                : null,
            licenseUrl: license.isEmpty ? null : license,
            truckPhotoUrl: truckPhoto.isEmpty ? null : truckPhoto,
          );
      if (!mounted) return;
      await context.read<AuthCubit>().refreshUser();
      // routerRedirect now sees role == driver and sends us to the driver
      // shell; nothing else to do here.
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.becomeDriverTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.becomeDriverIntro),
              const SizedBox(height: 24),
              SegmentedButton<_RegistrationMode>(
                key: const Key('registrationModeSelector'),
                segments: [
                  ButtonSegment(
                    value: _RegistrationMode.ownTruck,
                    label: Text(l10n.becomeDriverModeOwnTruck),
                  ),
                  ButtonSegment(
                    value: _RegistrationMode.invite,
                    label: Text(l10n.becomeDriverModeInvite),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 16),
              if (_mode == _RegistrationMode.invite) ...[
                Text(l10n.becomeDriverInviteIntro),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('inviteTokenField'),
                  controller: _inviteTokenController,
                  decoration: InputDecoration(
                    labelText: l10n.inviteTokenFieldLabel,
                    hintText: l10n.inviteTokenFieldHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                TextField(
                  key: const Key('plateField'),
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.plateFieldLabel,
                    hintText: l10n.plateFieldHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(l10n.truckTypeFieldLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TruckType>(
                  key: const Key('truckTypeSelector'),
                  segments: [
                    for (final type in TruckType.values)
                      ButtonSegment(value: type, label: Text(type.label(l10n))),
                  ],
                  selected: {_truckType},
                  onSelectionChanged: (selection) =>
                      setState(() => _truckType = selection.first),
                ),
                const SizedBox(height: 16),
                Text(l10n.capacityFieldLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TruckCapacity>(
                  key: const Key('capacitySelector'),
                  segments: [
                    for (final capacity in TruckCapacity.values)
                      ButtonSegment(
                        value: capacity,
                        label: Text(capacity.label(l10n)),
                      ),
                  ],
                  selected: {_capacity},
                  onSelectionChanged: (selection) =>
                      setState(() => _capacity = selection.first),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('licenseUrlField'),
                controller: _licenseUrlController,
                decoration: InputDecoration(
                  labelText: l10n.licenseUrlFieldLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('truckPhotoUrlField'),
                controller: _truckPhotoUrlController,
                decoration: InputDecoration(
                  labelText: l10n.truckPhotoUrlFieldLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.becomeDriverSubmitError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('becomeDriverSubmitButton'),
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.becomeDriverSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
