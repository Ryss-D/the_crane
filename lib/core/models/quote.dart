import 'package:freezed_annotation/freezed_annotation.dart';

import 'job.dart';

part 'quote.freezed.dart';
part 'quote.g.dart';

/// A fare quote from `POST /v1/jobs/quote` (JOB-4).
///
/// Prices are integer COP. The backend caches the quote (~10 min) under
/// [quoteId]; jobs are created from that id.
@freezed
abstract class Quote with _$Quote {
  const factory Quote({
    required String quoteId,
    required VehicleType vehicleType,
    required int price,
    @Default('COP') String currency,
    required int etaMinutes,
    required double distanceKm,
    DateTime? expiresAt,
  }) = _Quote;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);
}
