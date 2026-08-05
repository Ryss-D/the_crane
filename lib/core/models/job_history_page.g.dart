// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_history_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobHistoryPage _$JobHistoryPageFromJson(Map<String, dynamic> json) =>
    _JobHistoryPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => Job.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );

Map<String, dynamic> _$JobHistoryPageToJson(_JobHistoryPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
    };
