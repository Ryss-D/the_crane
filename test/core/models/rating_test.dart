import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/rating.dart';

void main() {
  group('Rating', () {
    final rating = Rating(
      id: 'rating-1',
      jobId: 'job-1',
      fromUserId: 'user-1',
      toUserId: 'user-2',
      stars: 5,
      comment: 'Great service',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('json round-trip preserves all fields', () {
      final restored = Rating.fromJson(rating.toJson());
      expect(restored, rating);
    });

    test('serializes snake_case keys', () {
      final json = rating.toJson();
      expect(json['job_id'], 'job-1');
      expect(json['from_user_id'], 'user-1');
      expect(json['to_user_id'], 'user-2');
      expect(json['created_at'], rating.createdAt.toIso8601String());
    });

    test('parses backend-shaped json, comment optional', () {
      final parsed = Rating.fromJson(const {
        'id': 'r1',
        'job_id': 'j1',
        'from_user_id': 'u1',
        'to_user_id': 'u2',
        'stars': 4,
        'comment': null,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(parsed.stars, 4);
      expect(parsed.comment, isNull);
    });

    test('coerces an int-typed stars value from json', () {
      // `(json['stars'] as num).toInt()` — guards against the backend ever
      // sending a non-int-literal num for an integer column.
      final parsed = Rating.fromJson(const {
        'id': 'r2',
        'job_id': 'j1',
        'from_user_id': 'u1',
        'to_user_id': 'u2',
        'stars': 3,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(parsed.stars, 3);
      expect(parsed.comment, isNull);
    });
  });
}
