import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/truck.dart';

void main() {
  group('JobStatus', () {
    test('wire values mirror the backend state machine exactly', () {
      expect(JobStatus.values.map((s) => s.wire), [
        'requested',
        'matching',
        'assigned',
        'en_route_pickup',
        'arrived_pickup',
        'loading',
        'in_transit',
        'delivered',
        'completed',
        'cancelled',
        'no_drivers',
      ]);
    });

    test('driver advance cycle walks the happy path in order', () {
      final visited = <JobStatus>[];
      JobStatus? current = JobStatus.assigned;
      while (current != null) {
        visited.add(current);
        current = current.nextDriverStatus;
      }
      expect(visited, [
        JobStatus.assigned,
        JobStatus.enRoutePickup,
        JobStatus.arrivedPickup,
        JobStatus.loading,
        JobStatus.inTransit,
        JobStatus.delivered,
        JobStatus.completed,
      ]);
    });

    test('terminal states have no driver action', () {
      expect(JobStatus.completed.nextDriverStatus, isNull);
      expect(JobStatus.cancelled.nextDriverStatus, isNull);
      expect(JobStatus.noDrivers.nextDriverStatus, isNull);
      expect(JobStatus.matching.nextDriverStatus, isNull);
      expect(JobStatus.completed.isTerminal, isTrue);
      expect(JobStatus.inTransit.isTerminal, isFalse);
    });
  });

  group('Job', () {
    // Shaped like a real `GET /v1/jobs/{id}` response (PLAN §2.2).
    const backendPayload = {
      'id': '7f9b7f2a-0000-1111-2222-333344445555',
      'customer_id': 'cus-001',
      'driver_id': 'drv-001',
      'status': 'en_route_pickup',
      'vehicle_type': 'moto',
      'pickup': {'lat': 6.2529, 'lng': -75.5646},
      'pickup_address': 'Cl. 10 #43E-31, El Poblado, Medellín',
      'dropoff': {'lat': 6.1701, 'lng': -75.5871},
      'dropoff_address': 'Cra. 48 #32B Sur-139, Envigado',
      'distance_km': 11.2,
      'quoted_price': 98600,
      'final_price': null,
      'payment_method': 'cash',
      'driver': {
        'id': 'drv-001',
        'name': 'Carlos Ramírez',
        'phone': '+573001112233',
        'truck_plate': 'TGX 123',
        'truck_type': 'flatbed',
        'rating_avg': 4.8,
        'photo_url': null,
      },
      'requested_at': '2026-08-04T14:03:21.000Z',
      'assigned_at': '2026-08-04T14:04:02.000Z',
      'picked_up_at': null,
      'completed_at': null,
      'cancelled_at': null,
      'cancel_reason': null,
    };

    test('parses a backend-shaped payload', () {
      final job = Job.fromJson(backendPayload);
      expect(job.status, JobStatus.enRoutePickup);
      expect(job.vehicleType, VehicleType.moto);
      expect(job.pickup, const LatLng(lat: 6.2529, lng: -75.5646));
      expect(job.dropoffAddress, 'Cra. 48 #32B Sur-139, Envigado');
      expect(job.distanceKm, 11.2);
      expect(job.quotedPrice, 98600);
      expect(job.finalPrice, isNull);
      expect(job.paymentMethod, 'cash');
      expect(job.driver?.name, 'Carlos Ramírez');
      expect(job.driver?.truckType, TruckType.flatbed);
      expect(job.requestedAt, DateTime.parse('2026-08-04T14:03:21.000Z'));
      expect(job.pickedUpAt, isNull);
    });

    test('json round-trip preserves all fields', () {
      final job = Job.fromJson(backendPayload);
      final restored = Job.fromJson(job.toJson());
      expect(restored, job);
    });

    test('serializes snake_case keys and wire enum values', () {
      final json = Job.fromJson(backendPayload).toJson();
      expect(json['status'], 'en_route_pickup');
      expect(json['vehicle_type'], 'moto');
      expect(json['customer_id'], 'cus-001');
      expect(json['pickup_address'], isA<String>());
      expect(json['distance_km'], 11.2);
      expect(json['quoted_price'], 98600);
      expect((json['driver'] as Map)['truck_plate'], 'TGX 123');
      expect((json['driver'] as Map)['rating_avg'], 4.8);
    });

    test('no_drivers status parses', () {
      final job = Job.fromJson({
        ...backendPayload,
        'status': 'no_drivers',
        'driver_id': null,
        'driver': null,
        'assigned_at': null,
      });
      expect(job.status, JobStatus.noDrivers);
      expect(job.driver, isNull);
    });
  });
}
