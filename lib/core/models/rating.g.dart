// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Rating _$RatingFromJson(Map<String, dynamic> json) => _Rating(
  id: json['id'] as String,
  jobId: json['job_id'] as String,
  fromUserId: json['from_user_id'] as String,
  toUserId: json['to_user_id'] as String,
  stars: (json['stars'] as num).toInt(),
  comment: json['comment'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$RatingToJson(_Rating instance) => <String, dynamic>{
  'id': instance.id,
  'job_id': instance.jobId,
  'from_user_id': instance.fromUserId,
  'to_user_id': instance.toUserId,
  'stars': instance.stars,
  'comment': instance.comment,
  'created_at': instance.createdAt.toIso8601String(),
};
