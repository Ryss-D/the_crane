import 'package:freezed_annotation/freezed_annotation.dart';

import 'job.dart';

part 'job_history_page.freezed.dart';
part 'job_history_page.g.dart';

/// One page of `GET /v1/jobs?role=..&limit=..&offset=..` (JOB-5, RAT-3):
/// the caller's job history, newest first.
@freezed
abstract class JobHistoryPage with _$JobHistoryPage {
  const factory JobHistoryPage({
    required List<Job> items,
    required int total,
    required int limit,
    required int offset,
  }) = _JobHistoryPage;

  factory JobHistoryPage.fromJson(Map<String, dynamic> json) =>
      _$JobHistoryPageFromJson(json);
}
