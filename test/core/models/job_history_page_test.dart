import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_history_page.dart';
import 'package:the_crane/core/models/lat_lng.dart';

Job _job(String id) => Job(
  id: id,
  customerId: 'cust-1',
  status: JobStatus.completed,
  vehicleType: VehicleType.car,
  pickup: const LatLng(lat: 6.2, lng: -75.5),
  pickupAddress: 'Origin',
  dropoff: const LatLng(lat: 6.1, lng: -75.6),
  dropoffAddress: 'Destination',
  distanceKm: 5,
  quotedPrice: 50000,
  requestedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('JobHistoryPage', () {
    final page = JobHistoryPage(
      items: [_job('job-1'), _job('job-2')],
      total: 7,
      limit: 2,
      offset: 0,
    );

    test('json round-trip preserves all fields', () {
      final restored = JobHistoryPage.fromJson(page.toJson());
      expect(restored, page);
    });

    test('serializes items as a list of full job json objects', () {
      final json = page.toJson();
      expect(json['items'], hasLength(2));
      expect((json['items'] as List)[0]['id'], 'job-1');
      expect(json['total'], 7);
      expect(json['limit'], 2);
      expect(json['offset'], 0);
    });

    test('parses an empty page', () {
      final parsed = JobHistoryPage.fromJson(const {
        'items': <dynamic>[],
        'total': 0,
        'limit': 20,
        'offset': 0,
      });
      expect(parsed.items, isEmpty);
      expect(parsed.total, 0);
    });

    test('parses a page whose offset is beyond total (last page cut-off)',
        () {
      final parsed = JobHistoryPage.fromJson(const {
        'items': <dynamic>[],
        'total': 7,
        'limit': 20,
        'offset': 20,
      });
      expect(parsed.items, isEmpty);
      expect(parsed.offset, 20);
      expect(parsed.total, 7);
    });
  });
}
