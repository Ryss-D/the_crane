import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/models/driver_balance.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import 'driver_balance_cubit.dart';

/// DRV-5 — the driver's owed commission balance plus recent settlements.
/// The app bar's list icon leads to DRV-6's services-per-period breakdown.
///
/// PAY-3: also offers "Liquidar saldo" — starts a Wompi checkout via
/// [DriverBalanceCubit.settle]. The balance itself only moves once Wompi's
/// webhook reports the payment approved, so this screen never optimistically
/// updates [DriverBalanceState.balance] after a settlement request; it just
/// confirms the request was sent.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  Future<void> _openSettleDialog(BuildContext context, int owedCents) async {
    final cubit = context.read<DriverBalanceCubit>();
    final result = await showDialog<({int amount, SettlementPaymentMethod method})>(
      context: context,
      builder: (dialogContext) => _SettleDialog(maxAmount: owedCents),
    );
    if (result == null) return;
    await cubit.settle(amountCop: result.amount, method: result.method);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<DriverBalanceCubit, DriverBalanceState>(
      listenWhen: (previous, current) =>
          (current.lastCheckout != null && current.lastCheckout != previous.lastCheckout) ||
          (current.settlementError != null && current.settlementError != previous.settlementError),
      listener: (context, state) async {
        final cubit = context.read<DriverBalanceCubit>();
        final checkout = state.lastCheckout;
        final error = state.settlementError;
        if (checkout != null) {
          final url = checkout.asyncPaymentUrl;
          if (url != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.earningsSettleSentRedirectBody)),
            );
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.earningsSettleSentNequiBody)),
            );
          }
        } else if (error != null) {
          // 503 ("...not configured") is the expected, common state right
          // now -- no real Wompi account exists yet -- so it gets its own,
          // clearer message instead of the generic one.
          final isUnavailable = error.toLowerCase().contains('not configured');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isUnavailable
                    ? l10n.earningsSettleUnavailableError
                    : l10n.earningsSettleGenericError,
              ),
            ),
          );
        }
        cubit.clearSettlementResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.earningsTitle),
          actions: [
            IconButton(
              key: const Key('servicesPeriodNavButton'),
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: l10n.servicesPeriodTitle,
              onPressed: () => context.push(AppRoute.driverServicesPeriod),
            ),
          ],
        ),
        body: SafeArea(
          child: BlocBuilder<DriverBalanceCubit, DriverBalanceState>(
            builder: (context, state) {
              final balance = state.balance;
              if (state.isLoading && balance == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.loadFailed && balance == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.earningsLoadError),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.read<DriverBalanceCubit>().load(),
                        child: Text(l10n.retryButton),
                      ),
                    ],
                  ),
                );
              }
              if (balance == null) return const SizedBox.shrink();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.earningsOwedLabel),
                          const SizedBox(height: 4),
                          Text(
                            formatCop(balance.owedCents),
                            key: const Key('earningsOwedAmount'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (balance.balanceCapCents != null) ...[
                            const SizedBox(height: 12),
                            Text(l10n.earningsCapLabel),
                            Text(formatCop(balance.balanceCapCents!)),
                          ],
                          if (balance.owedCents > 0) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('settleBalanceButton'),
                              onPressed: state.isSettling
                                  ? null
                                  : () => _openSettleDialog(context, balance.owedCents),
                              child: state.isSettling
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(l10n.earningsSettleButton),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.earningsSettlementsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (balance.recentSettlements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l10n.earningsNoSettlementsBody),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final settlement in balance.recentSettlements)
                            ListTile(
                              key: Key('settlementRow_${settlement.id}'),
                              title: Text(formatCop(settlement.amountCents)),
                              subtitle: Text(
                                settlement.note == null
                                    ? formatHistoryDate(settlement.settledAt)
                                    : '${formatHistoryDate(settlement.settledAt)} · ${settlement.note}',
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// PAY-3 — amount + payment-method picker for a settlement request.
/// Prefilled with the full owed balance; the driver can settle less.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.maxAmount});

  final int maxAmount;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final _amountController = TextEditingController(text: widget.maxAmount.toString());
  SettlementPaymentMethod _method = SettlementPaymentMethod.nequi;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountController.text.trim());

  bool get _canSubmit {
    final amount = _amount;
    return amount != null && amount > 0 && amount <= widget.maxAmount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.earningsSettleDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('settleAmountField'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.earningsSettleAmountLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(l10n.earningsSettleMethodLabel),
          const SizedBox(height: 8),
          SegmentedButton<SettlementPaymentMethod>(
            key: const Key('settleMethodSelector'),
            segments: [
              ButtonSegment(
                value: SettlementPaymentMethod.nequi,
                label: Text(l10n.earningsSettleMethodNequi),
              ),
              ButtonSegment(
                value: SettlementPaymentMethod.pse,
                label: Text(l10n.earningsSettleMethodPse),
              ),
              ButtonSegment(
                value: SettlementPaymentMethod.card,
                label: Text(l10n.earningsSettleMethodCard),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (selection) => setState(() => _method = selection.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('settleSubmitButton'),
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop((amount: _amount!, method: _method))
              : null,
          child: Text(l10n.earningsSettleSubmitButton),
        ),
      ],
    );
  }
}
