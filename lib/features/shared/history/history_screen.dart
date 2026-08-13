import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/job.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../labels.dart';
import 'history_cubit.dart';
import 'history_detail_screen.dart';

/// RAT-3 — paginated trip history, shared by both roles. `HistoryCubit.role`
/// picks which side of `JobsRepository.listHistory` to call; this screen
/// doesn't know or care which.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: SafeArea(
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            if (state.isLoading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed && state.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.historyLoadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.read<HistoryCubit>().load(),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            }
            if (state.items.isEmpty) {
              return Center(child: Text(l10n.historyEmptyBody));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: state.isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              key: const Key('historyLoadMoreButton'),
                              onPressed: () =>
                                  context.read<HistoryCubit>().loadMore(),
                              child: Text(l10n.historyLoadMoreButton),
                            ),
                    ),
                  );
                }
                final job = state.items[index];
                return _HistoryRow(
                  job: job,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryDetailScreen(job: job),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One row: date, short addresses, price, and a status pill.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListTile(
      key: Key('historyRow_${job.id}'),
      onTap: onTap,
      title: Text(
        '${job.pickupAddress} → ${job.dropoffAddress}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(formatHistoryDate(job.requestedAt)),
      // `ListTile` caps a trailing widget's height at 56 regardless of the
      // tile being two-line (Flutter's own `maxIconHeightConstraint`), which
      // this price-over-chip stack alone slightly exceeds. `FittedBox`
      // scales it down just enough to fit rather than overflow.
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCop(job.finalPrice ?? job.quotedPrice),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                job.status.label(l10n),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
