import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/ws/server_message.dart';

void main() {
  group('ServerMessage.fromWire subscribed/unsubscribed', () {
    test('subscribed parses a valid job_id', () {
      final message =
          ServerMessage.fromWire({'type': 'subscribed', 'job_id': 'job-1'});
      expect(message, const ServerMessage.subscribed(jobId: 'job-1'));
    });

    test('subscribed with a non-string job_id falls back to unknown', () {
      final raw = {'type': 'subscribed', 'job_id': 123};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });

    test('subscribed with no job_id at all falls back to unknown', () {
      final raw = {'type': 'subscribed'};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });

    test('unsubscribed parses a valid job_id', () {
      final message =
          ServerMessage.fromWire({'type': 'unsubscribed', 'job_id': 'job-2'});
      expect(message, const ServerMessage.unsubscribed(jobId: 'job-2'));
    });

    test('unsubscribed with a non-string job_id falls back to unknown', () {
      final raw = {'type': 'unsubscribed', 'job_id': null};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });
  });

  group('ServerMessage.fromWire job_event', () {
    test('parses a valid jobId/status pair', () {
      final message = ServerMessage.fromWire({
        'type': 'job_event',
        'job_id': 'job-3',
        'status': 'assigned',
      });
      expect(
        message,
        const ServerMessage.jobEvent(jobId: 'job-3', status: 'assigned'),
      );
    });

    test('missing status falls back to unknown', () {
      final raw = {'type': 'job_event', 'job_id': 'job-3'};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });

    test('non-string status falls back to unknown', () {
      final raw = {'type': 'job_event', 'job_id': 'job-3', 'status': 7};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });
  });

  group('ServerMessage.fromWire driver_location', () {
    test('parses lat/lng as ints or doubles into doubles', () {
      final message = ServerMessage.fromWire({
        'type': 'driver_location',
        'job_id': 'job-4',
        'lat': 6,
        'lng': -75,
      });
      expect(
        message,
        const ServerMessage.driverLocation(
          jobId: 'job-4',
          lat: 6.0,
          lng: -75.0,
        ),
      );
    });

    test('non-numeric lat falls back to unknown', () {
      final raw = {
        'type': 'driver_location',
        'job_id': 'job-4',
        'lat': 'not-a-number',
        'lng': -75.0,
      };
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });
  });

  group('ServerMessage.fromWire job_offer', () {
    const rawOffer = {
      'type': 'job_offer',
      'job_id': 'job-1',
      'offer_id': 'off-1',
      'vehicle_type': 'car',
      'pickup': {'lat': 6.24, 'lng': -75.58},
      'dropoff': {'lat': 6.20, 'lng': -75.57},
      'quoted_price': 100000,
      'expires_in_seconds': 30,
    };

    test(
      'parses the real backend fields once they exist (DRV-2 enrichment)',
      () {
        final message = ServerMessage.fromWire({
          ...rawOffer,
          'pickup_distance_km': 2.35,
          'commission_amount': 15000,
        });
        final offer = message as ServerMessageJobOffer;
        expect(offer.pickupDistanceKm, 2.35);
        expect(offer.commissionAmount, 15000);
      },
    );

    test(
      'both fields parse as null when absent, so callers can fall back '
      'to their own approximation',
      () {
        final message = ServerMessage.fromWire(rawOffer);
        final offer = message as ServerMessageJobOffer;
        expect(offer.pickupDistanceKm, isNull);
        expect(offer.commissionAmount, isNull);
      },
    );

    test('quoted_price absent parses as null', () {
      final withoutPrice = {...rawOffer}..remove('quoted_price');
      final message = ServerMessage.fromWire(withoutPrice);
      final offer = message as ServerMessageJobOffer;
      expect(offer.quotedPrice, isNull);
      expect(offer.pickup, const LatLng(lat: 6.24, lng: -75.58));
      expect(offer.dropoff, const LatLng(lat: 6.20, lng: -75.57));
      expect(offer.expiresInSeconds, 30);
    });

    test('an unrecognized vehicle_type falls back to VehicleType.car', () {
      final message = ServerMessage.fromWire({
        ...rawOffer,
        'vehicle_type': 'spaceship',
      });
      final offer = message as ServerMessageJobOffer;
      expect(offer.vehicleType, VehicleType.car);
    });

    test('parses moto/suv vehicle_type wire values exactly', () {
      final moto = ServerMessage.fromWire({...rawOffer, 'vehicle_type': 'moto'})
          as ServerMessageJobOffer;
      expect(moto.vehicleType, VehicleType.moto);
      final suv = ServerMessage.fromWire({...rawOffer, 'vehicle_type': 'suv'})
          as ServerMessageJobOffer;
      expect(suv.vehicleType, VehicleType.suv);
    });

    test('missing pickup falls back to unknown rather than throwing', () {
      final raw = {...rawOffer}..remove('pickup');
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });

    test('missing expires_in_seconds falls back to unknown', () {
      final raw = {...rawOffer}..remove('expires_in_seconds');
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });
  });

  group('ServerMessage.fromWire error', () {
    test('uses detail when present', () {
      final message = ServerMessage.fromWire({
        'type': 'error',
        'detail': 'invalid job id',
      });
      expect(message, const ServerMessage.error(detail: 'invalid job id'));
    });

    test('falls back to message when detail is absent', () {
      final message = ServerMessage.fromWire({
        'type': 'error',
        'message': 'legacy field name',
      });
      expect(message, const ServerMessage.error(detail: 'legacy field name'));
    });

    test('falls back to a placeholder when neither field is a string', () {
      final message = ServerMessage.fromWire({'type': 'error'});
      expect(message, const ServerMessage.error(detail: 'Unknown error'));
    });
  });

  group('ServerMessage.fromWire ping', () {
    test('parses regardless of any other fields present', () {
      final message = ServerMessage.fromWire({'type': 'ping', 'ts': 123});
      expect(message, const ServerMessage.ping());
    });
  });

  group('ServerMessage.fromWire unknown', () {
    test('an unrecognized type is kept as unknown with the raw payload', () {
      final raw = {'type': 'something_new', 'foo': 'bar'};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });

    test('a missing type field is also unknown', () {
      final raw = {'job_id': 'job-1'};
      final message = ServerMessage.fromWire(raw);
      expect(message, ServerMessage.unknown(raw: raw));
    });
  });
}
