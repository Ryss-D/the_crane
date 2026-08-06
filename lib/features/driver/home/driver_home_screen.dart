import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/api/drivers_repository.dart';
import '../../../core/api/fake_drivers_repository.dart';
import '../../../core/models/driver_profile.dart';
import '../../../core/models/job.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/labels.dart';
import '../../shared/widgets/map_placeholder.dart';
import '../job/active_job_cubit.dart';
import 'driver_home_cubit.dart';
import 'offer_cubit.dart';
import 'offer_sheet.dart';

/// DRV-1 — driver home: map area, availability toggle, blocked banner, and
/// the incoming-offer sheet trigger (DRV-2).
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _offerSheetOpen = false;

  void _showOfferSheet() {
    if (_offerSheetOpen) return;
    _offerSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      // The modal route lives on the root navigator, outside the driver
      // shell, so the cubits must be re-provided to the sheet subtree.
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<OfferCubit>()),
          BlocProvider.value(value: context.read<ActiveJobCubit>()),
        ],
        child: const OfferSheet(),
      ),
    ).whenComplete(() => _offerSheetOpen = false);
  }

  void _dismissOfferSheet() {
    if (!_offerSheetOpen) return;
    // Pop from the same (shell) navigator showModalBottomSheet pushed onto.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return MultiBlocListener(
      listeners: [
        // The offer sheet's lifecycle mirrors the offer state: shown when an
        // offer arrives, dismissed on accept/reject/timeout.
        BlocListener<OfferCubit, ActiveOffer?>(
          listenWhen: (previous, current) =>
              (previous == null) != (current == null),
          listener: (context, state) =>
              state != null ? _showOfferSheet() : _dismissOfferSheet(),
        ),
        // Accepting an offer seeds the active job → navigate to DRV-3.
        BlocListener<ActiveJobCubit, Job?>(
          listenWhen: (previous, current) =>
              previous == null && current != null,
          listener: (context, state) => context.push(AppRoute.driverJob),
        ),
      ],
      child: BlocBuilder<DriverHomeCubit, DriverHomeState>(
        builder: (context, state) {
          final available = state.status == DriverStatus.available;
          final driversRepo = context.read<DriversRepository>();

          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.driverHomeTitle),
              actions: [
                IconButton(
                  key: const Key('earningsNavButton'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  tooltip: l10n.earningsTitle,
                  onPressed: () => context.push(AppRoute.driverEarnings),
                ),
                IconButton(
                  key: const Key('historyNavButton'),
                  icon: const Icon(Icons.history),
                  tooltip: l10n.historyTitle,
                  onPressed: () => context.push(AppRoute.driverHistory),
                ),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.isBlocked)
                      Card(
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.gpp_maybe_outlined,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state.blockReason ==
                                          DriverBlockReason.adminBlocked
                                      ? l10n.blockedBannerAdmin
                                      : l10n.blockedBannerUnverified,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Expanded(child: MapPlaceholder()),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: available
                              ? Colors.green
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.status.label(l10n),
                          key: const Key('driverStatusLabel'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      available ? l10n.availableHint : l10n.offlineHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('availabilityToggle'),
                      style: available
                          ? FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            )
                          : null,
                      onPressed: state.isUpdating
                          ? null
                          : context
                              .read<DriverHomeCubit>()
                              .toggleAvailability,
                      child: state.isUpdating
                          ? const SizedBox.square(
                              dimension: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              available
                                  ? l10n.goOfflineButton
                                  : l10n.goAvailableButton,
                            ),
                    ),
                    // Dev-only stand-in for the DSP-2 offer push until the
                    // WebSocket (TRK-4) delivers real offers.
                    if (driversRepo is FakeDriversRepository) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('devTriggerOfferButton'),
                        icon: const Icon(Icons.bolt),
                        onPressed:
                            available ? driversRepo.debugTriggerOffer : null,
                        label: Text(l10n.devTriggerOfferButton),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
