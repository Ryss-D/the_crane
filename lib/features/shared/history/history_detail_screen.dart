import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/models/rating.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../labels.dart';
import '../widgets/map_placeholder.dart';

/// RAT-3 detail view for one history row: fuller job info plus any ratings
/// either side left. No live map — [MapPlaceholder] stands in until FND-6
/// (a past trip has no live position to show anyway, only a static route
/// would ever make sense here).
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.job});

  final Job job;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late final Future<List<Rating>> _ratingsFuture =
      context.read<JobsRepository>().getRatings(widget.job.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyDetailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 140, child: MapPlaceholder()),
            const SizedBox(height: 16),
            Center(
              child: Chip(
                key: const Key('historyDetailStatusChip'),
                label: Text(job.status.label(l10n)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                formatHistoryDate(job.requestedAt),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(height: 32),
            _InfoRow(
              icon: Icons.trip_origin,
              label: l10n.pickupFieldLabel,
              value: job.pickupAddress,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.place_outlined,
              label: l10n.dropoffFieldLabel,
              value: job.dropoffAddress,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.fareLabel),
                Text(
                  formatCop(job.finalPrice ?? job.quotedPrice),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(l10n.ratingsSectionTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            FutureBuilder<List<Rating>>(
              future: _ratingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final ratings = snapshot.data ?? const <Rating>[];
                if (ratings.isEmpty) {
                  return Text(l10n.noRatingsBody);
                }
                return Column(
                  key: const Key('historyRatingsList'),
                  children: [
                    for (final rating in ratings)
                      _RatingRow(job: job, rating: rating),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// One rating row, labeled by comparing [Rating.fromUserId] against the
/// job's `customerId`/`driverId` — there's no real current-user identity to
/// key off yet (AUTH-3/4), but the direction of any given rating is always
/// unambiguous from the job it's attached to.
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.job, required this.rating});

  final Job job;
  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = rating.fromUserId == job.customerId
        ? l10n.ratingFromCustomerLabel
        : l10n.ratingFromDriverLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                if (rating.comment != null && rating.comment!.isNotEmpty)
                  Text(rating.comment!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text('${rating.stars}'),
            ],
          ),
        ],
      ),
    );
  }
}
