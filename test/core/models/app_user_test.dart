import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/models/app_user.dart';

void main() {
  group('AppUser', () {
    const user = AppUser(
      id: 'a3f0c1d2-1111-2222-3333-444455556666',
      firebaseUid: 'fb_abc123',
      role: UserRole.fleetOwner,
      name: 'Sebastián',
      phone: '+573001234567',
      email: 'sebas@example.com',
    );

    test('json round-trip preserves all fields', () {
      final restored = AppUser.fromJson(user.toJson());
      expect(restored, user);
    });

    test('serializes snake_case keys and snake_case roles', () {
      final json = user.toJson();
      expect(json['firebase_uid'], 'fb_abc123');
      expect(json['role'], 'fleet_owner');
      expect(json['fcm_token'], isNull);
    });

    test('parses backend-shaped json', () {
      final parsed = AppUser.fromJson(const {
        'id': 'u1',
        'firebase_uid': 'fb1',
        'role': 'driver',
        'name': 'Ana',
        'phone': '+573000000000',
        'email': null,
        'fcm_token': 'token-1',
      });
      expect(parsed.role, UserRole.driver);
      expect(parsed.fcmToken, 'token-1');
    });
  });
}
