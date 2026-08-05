// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobOffer _$JobOfferFromJson(Map<String, dynamic> json) => _JobOffer(
  offerId: json['offer_id'] as String,
  job: Job.fromJson(json['job'] as Map<String, dynamic>),
  pickupDistanceKm: (json['pickup_distance_km'] as num).toDouble(),
  commissionAmount: (json['commission_amount'] as num).toInt(),
  ttlSeconds: (json['ttl_seconds'] as num).toInt(),
  offeredAt: DateTime.parse(json['offered_at'] as String),
);

Map<String, dynamic> _$JobOfferToJson(_JobOffer instance) => <String, dynamic>{
  'offer_id': instance.offerId,
  'job': instance.job.toJson(),
  'pickup_distance_km': instance.pickupDistanceKm,
  'commission_amount': instance.commissionAmount,
  'ttl_seconds': instance.ttlSeconds,
  'offered_at': instance.offeredAt.toIso8601String(),
};
