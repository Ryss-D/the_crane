import 'package:freezed_annotation/freezed_annotation.dart';

import 'job.dart';

part 'job_offer.freezed.dart';
part 'job_offer.g.dart';

/// A dispatch offer pushed to a driver (DSP-2 / DRV-2).
///
/// Carries the job plus offer-specific data the sheet needs: distance to the
/// pickup, the platform commission preview and the TTL countdown.
@freezed
abstract class JobOffer with _$JobOffer {
  const factory JobOffer({
    required String offerId,
    required Job job,
    required double pickupDistanceKm,
    required int commissionAmount,
    required int ttlSeconds,
    required DateTime offeredAt,
  }) = _JobOffer;

  factory JobOffer.fromJson(Map<String, dynamic> json) =>
      _$JobOfferFromJson(json);
}
