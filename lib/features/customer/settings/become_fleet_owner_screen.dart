import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/fleet_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_cubit.dart';

/// FLT-1 (Flutter half) — a signed-in customer becomes a fleet owner: just
/// a fleet name, mirroring AUTH-5's "become a driver" entry point.
///
/// On success the backend has already flipped the caller's role to
/// `fleet_owner` server-side. [AuthCubit.refreshUser] re-syncs the local
/// profile so `routerRedirect` (`lib/app/router.dart`) lands on the fleet
/// shell on its next redirect evaluation — no explicit navigation is done
/// here, same pattern as `BecomeDriverScreen`.
class BecomeFleetOwnerScreen extends StatefulWidget {
  const BecomeFleetOwnerScreen({super.key});

  @override
  State<BecomeFleetOwnerScreen> createState() =>
      _BecomeFleetOwnerScreenState();
}

class _BecomeFleetOwnerScreenState extends State<BecomeFleetOwnerScreen> {
  final _nameController = TextEditingController();
  bool _submitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _nameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await context
          .read<FleetRepository>()
          .createFleet(name: _nameController.text.trim());
      if (!mounted) return;
      await context.read<AuthCubit>().refreshUser();
      // routerRedirect now sees role == fleetOwner and sends us to the
      // fleet shell; nothing else to do here.
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
      appBar: AppBar(title: Text(l10n.becomeFleetOwnerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.becomeFleetOwnerIntro),
              const SizedBox(height: 24),
              TextField(
                key: const Key('fleetNameField'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fleetNameFieldLabel,
                  hintText: l10n.fleetNameFieldHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.becomeFleetOwnerSubmitError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('becomeFleetOwnerSubmitButton'),
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.becomeFleetOwnerSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
