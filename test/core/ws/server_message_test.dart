import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/ws/server_message.dart';

void main() {
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
  });
}
