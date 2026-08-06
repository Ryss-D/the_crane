import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/job_offer.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/quote.dart';
import 'package:the_crane/core/models/saved_vehicle.dart';
import 'package:the_crane/core/models/truck.dart';

void main() {
  group('Quote', () {
    const backendPayload = {
      'quote_id': 'qt_8f31ab',
      'vehicle_type': 'suv',
      'price': 132500,
      'currency': 'COP',
      'eta_minutes': 14,
      'distance_km': 7.8,
      'expires_at': '2026-08-04T14:13:21.000Z',
    };

    test('parses and round-trips a backend payload', () {
      final quote = Quote.fromJson(backendPayload);
      expect(quote.quoteId, 'qt_8f31ab');
      expect(quote.vehicleType, VehicleType.suv);
      expect(quote.price, 132500);
      expect(quote.currency, 'COP');
      expect(quote.etaMinutes, 14);
      expect(quote.distanceKm, 7.8);
      expect(Quote.fromJson(quote.toJson()), quote);
      expect(quote.toJson()['quote_id'], 'qt_8f31ab');
      expect(quote.toJson()['eta_minutes'], 14);
    });
  });

  group('Truck', () {
    const backendPayload = {
      'id': 'trk-9',
      'driver_id': 'drv-001',
      'fleet_id': null,
      'plate': 'TGX 123',
      'type': 'moto_only',
      'capacity': 'moto',
      'make': 'Chevrolet',
      'model': 'NHR',
    };

    test('parses and round-trips a backend payload', () {
      final truck = Truck.fromJson(backendPayload);
      expect(truck.type, TruckType.motoOnly);
      expect(truck.capacity, TruckCapacity.moto);
      expect(truck.fleetId, isNull);
      expect(Truck.fromJson(truck.toJson()), truck);
      expect(truck.toJson()['type'], 'moto_only');
      expect(truck.toJson()['driver_id'], 'drv-001');
    });
  });

  group('DriverProfile', () {
    // Backend shape (`DriverProfileRead` in
    // `backend/app/schemas/driver.py`): truck info nests under `truck`
    // (a `TruckRead`), not flat `truck_plate`/`truck_type`/`capacity` keys —
    // an earlier version of `DriverProfile` had those flat fields instead,
    // which silently parsed to null against this exact payload.
    const backendPayload = {
      'id': 'drv-profile-1',
      'user_id': 'drv-001',
      'status': 'on_job',
      'verified': true,
      'license_url': null,
      'truck_photo_url': null,
      'rating_avg': 4.8,
      'truck': {
        'id': 'trk-1',
        'driver_id': 'drv-001',
        'fleet_id': null,
        'plate': 'TGX 123',
        'type': 'flatbed',
        'capacity': 'both',
      },
    };

    test('parses and round-trips a backend payload', () {
      final profile = DriverProfile.fromJson(backendPayload);
      expect(profile.status, DriverStatus.onJob);
      expect(profile.verified, isTrue);
      expect(profile.truck, isNotNull);
      expect(profile.truck!.plate, 'TGX 123');
      expect(profile.truck!.type, TruckType.flatbed);
      expect(profile.truck!.capacity, TruckCapacity.both);
      expect(DriverProfile.fromJson(profile.toJson()), profile);
      expect(profile.toJson()['status'], 'on_job');
      expect(profile.toJson()['rating_avg'], 4.8);
      expect((profile.toJson()['truck'] as Map)['plate'], 'TGX 123');
    });

    test('rating defaults to 0 and truck is null when missing', () {
      final profile = DriverProfile.fromJson(const {
        'user_id': 'drv-002',
        'status': 'offline',
        'verified': false,
      });
      expect(profile.ratingAvg, 0);
      expect(profile.truck, isNull);
    });
  });

  group('SavedVehicle (CUS-6)', () {
    // Matches the `vehicles` API contract exactly:
    // GET /v1/me/vehicles -> [{"id", "type", "make", "model", "plate"}].
    const backendPayload = {
      'id': 'veh-1',
      'type': 'car',
      'make': 'Chevrolet',
      'model': 'Spark',
      'plate': 'ABC123',
    };

    test('parses and round-trips a backend payload', () {
      final vehicle = SavedVehicle.fromJson(backendPayload);
      expect(vehicle.type, VehicleType.car);
      expect(vehicle.make, 'Chevrolet');
      expect(vehicle.model, 'Spark');
      expect(vehicle.plate, 'ABC123');
      expect(SavedVehicle.fromJson(vehicle.toJson()), vehicle);
      expect(vehicle.toJson()['type'], 'car');
    });

    test('make/model are nullable', () {
      final vehicle = SavedVehicle.fromJson(const {
        'id': 'veh-2',
        'type': 'moto',
        'make': null,
        'model': null,
        'plate': 'XYZ987',
      });
      expect(vehicle.make, isNull);
      expect(vehicle.model, isNull);
      expect(vehicle.type, VehicleType.moto);
    });
  });

  group('JobOffer', () {
    test('round-trips with its embedded job', () {
      final offer = JobOffer(
        offerId: 'off-1',
        job: Job(
          id: 'job-1',
          customerId: 'cus-042',
          status: JobStatus.matching,
          vehicleType: VehicleType.car,
          pickup: const LatLng(lat: 6.2088, lng: -75.5679),
          pickupAddress: 'El Poblado',
          dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
          dropoffAddress: 'Sabaneta',
          distanceKm: 9.6,
          quotedPrice: 123200,
          requestedAt: DateTime.parse('2026-08-04T14:03:21.000Z'),
        ),
        pickupDistanceKm: 2.3,
        commissionAmount: 18500,
        ttlSeconds: 30,
        offeredAt: DateTime.parse('2026-08-04T14:05:00.000Z'),
      );
      expect(JobOffer.fromJson(offer.toJson()), offer);
      expect(offer.toJson()['ttl_seconds'], 30);
      expect((offer.toJson()['job'] as Map)['status'], 'matching');
    });
  });
}
