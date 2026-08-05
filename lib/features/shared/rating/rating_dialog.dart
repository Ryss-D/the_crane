import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../l10n/app_localizations.dart';

/// RAT-2 — star rating (1-5) + optional comment, offered after a job
/// reaches `completed` (both the customer's `MatchingScreen` and the
/// driver's `ActiveJobScreen` open this from a "Calificar viaje" button
/// rather than auto-popping it, so it never steals focus from the existing
/// "back to home" flow — entirely skippable by just not tapping it).
///
/// Returns `true` once [JobsRepository.submitRating] succeeds, `false` if
/// the dialog was skipped/dismissed without rating.
Future<bool> showRatingDialog(BuildContext context, {required String jobId}) {
  final jobsRepository = context.read<JobsRepository>();
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => RepositoryProvider.value(
      // The dialog attaches to the root navigator, outside whatever shell
      // provided the repository — re-provide it explicitly, same pattern
      // `DriverHomeScreen` uses for the offer bottom sheet.
      value: jobsRepository,
      child: _RatingDialog(jobId: jobId),
    ),
  ).then((value) => value ?? false);
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.jobId});

  final String jobId;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _submitting) return;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await context.read<JobsRepository>().submitRating(
            widget.jobId,
            stars: _stars,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.rateDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('ratingStar$i'),
                  onPressed:
                      _submitting ? null : () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          TextField(
            key: const Key('ratingCommentField'),
            controller: _commentController,
            enabled: !_submitting,
            decoration: InputDecoration(hintText: l10n.rateCommentHint),
            maxLines: 2,
          ),
          if (_failed) ...[
            const SizedBox(height: 8),
            Text(
              l10n.rateSubmitError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('skipRatingButton'),
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.skipRatingButton),
        ),
        FilledButton(
          key: const Key('submitRatingButton'),
          onPressed: _stars == 0 || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.submitRatingButton),
        ),
      ],
    );
  }
}
