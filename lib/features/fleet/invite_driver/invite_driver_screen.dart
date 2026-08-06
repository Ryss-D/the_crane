import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/fleet_repository.dart';
import '../../../core/models/fleet.dart';
import '../../../core/models/truck.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';

/// FLT-4 — "invitar conductor": a fleet owner invites a driver who doesn't
/// have a truck (or an account) yet, by phone. Pre-provisions the truck
/// server-side and hands back a token the invited driver redeems from
/// `BecomeDriverScreen`'s "tengo una invitación" path.
///
/// Sits alongside `AddTruckScreen`'s "agregar camión" flow (which only
/// covers a truck that's already unclaimed on the backend) rather than
/// replacing it — inviting is for a driver starting from nothing.
class InviteDriverScreen extends StatefulWidget {
  const InviteDriverScreen({super.key});

  @override
  State<InviteDriverScreen> createState() => _InviteDriverScreenState();
}

class _InviteDriverScreenState extends State<InviteDriverScreen> {
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  TruckType _truckType = TruckType.flatbed;
  TruckCapacity _capacity = TruckCapacity.both;
  bool _sending = false;
  bool _sendFailed = false;

  List<DriverInvite>? _invites;
  bool _loadingInvites = true;
  bool _invitesLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadInvites() async {
    setState(() {
      _loadingInvites = true;
      _invitesLoadFailed = false;
    });
    try {
      final invites = await context.read<FleetRepository>().listInvites();
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _loadingInvites = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingInvites = false;
          _invitesLoadFailed = true;
        });
      }
    }
  }

  bool get _canSend =>
      !_sending &&
      _phoneController.text.trim().isNotEmpty &&
      _plateController.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _sendFailed = false;
    });
    try {
      await context.read<FleetRepository>().createInvite(
            phone: _phoneController.text.trim(),
            plate: _plateController.text.trim(),
            truckType: _truckType,
            capacity: _capacity,
          );
      if (!mounted) return;
      _phoneController.clear();
      _plateController.clear();
      setState(() => _sending = false);
      await _loadInvites();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteDriverTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.inviteDriverIntro),
              const SizedBox(height: 24),
              TextField(
                key: const Key('invitePhoneField'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.invitePhoneFieldLabel,
                  hintText: l10n.signInPhoneHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('invitePlateField'),
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
                key: const Key('inviteTruckTypeSelector'),
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
                key: const Key('inviteCapacitySelector'),
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
              if (_sendFailed) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.inviteSendError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('inviteSendButton'),
                onPressed: _canSend ? _send : null,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.inviteSendButton),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.pendingInvitesTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _PendingInvitesList(
                invites: _invites,
                isLoading: _loadingInvites,
                loadFailed: _invitesLoadFailed,
                onRetry: _loadInvites,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingInvitesList extends StatelessWidget {
  const _PendingInvitesList({
    required this.invites,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
  });

  final List<DriverInvite>? invites;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading && invites == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (loadFailed && invites == null) {
      return Column(
        children: [
          Text(l10n.pendingInvitesLoadError),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.retryButton)),
        ],
      );
    }
    final items = invites ?? const <DriverInvite>[];
    if (items.isEmpty) {
      return Text(l10n.pendingInvitesEmptyBody);
    }
    return Card(
      child: Column(
        children: [
          for (final invite in items)
            ListTile(
              key: Key('pendingInviteRow_${invite.inviteToken}'),
              leading: const Icon(Icons.hourglass_top_outlined),
              title: Text(invite.phone),
            ),
        ],
      ),
    );
  }
}
