import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating.freezed.dart';
part 'rating.g.dart';

/// A single 1-5 star rating one side of a completed job left for the other
/// (RAT-1). Mirrors the backend `ratings` table
/// (`backend/app/models/rating.py`) and the future `POST /v1/jobs/{id}/rating`
/// / `GET /v1/jobs/{id}/ratings` responses.
///
/// Direction isn't a separate enum on the wire: compare [fromUserId] against
/// a job's `customerId`/`driverId` to label a rating as "customer → driver"
/// or "driver → customer" (see `lib/features/shared/history/`).
@freezed
abstract class Rating with _$Rating {
  const factory Rating({
    required String id,
    required String jobId,
    required String fromUserId,
    required String toUserId,
    required int stars,
    String? comment,
    required DateTime createdAt,
  }) = _Rating;

  factory Rating.fromJson(Map<String, dynamic> json) =>
      _$RatingFromJson(json);
}
