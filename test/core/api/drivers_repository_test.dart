import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/core/api/drivers_repository.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/truck.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/core/ws/server_message.dart';

class MockDio extends Mock implements Dio {}

class MockCraneSocket extends Mock implements CraneSocket {}

/// `POST /v1/drivers/me/register` / `PATCH /v1/drivers/me/status` response
/// shape, per `backend/app/schemas/driver.py::DriverProfileRead`.
Map<String, dynamic> _profileJson({
  String id = 'profile-1',
  String userId = 'user-1',
  String status = 'offline',
  bool verified = false,
  String? licenseUrl,
  String? truckPhotoUrl,
  Map<String, dynamic>? truck,
  double? ratingAvg,
}) => {
  'id': id,
  'user_id': userId,
  'status': status,
  'verified': verified,
  'license_url': licenseUrl,
  'truck_photo_url': truckPhotoUrl,
  'rating_avg': ratingAvg,
  'truck': truck,
};

/// `TruckRead` shape nested under `DriverProfileRead.truck`.
Map<String, dynamic> _truckJson({
  String id = 'truck-1',
  String? driverId = 'user-1',
  String? fleetId,
  String plate = 'XYZ987',
  String type = 'car',
  String capacity = 'car',
}) => {
  'id': id,
  'plate': plate,
  'type': type,
  'capacity': capacity,
  'driver_id': driverId,
  'fleet_id': fleetId,
  'driver_status': null,
  'driver_name': null,
};

/// `GET /v1/drivers/me/balance` response shape, per
/// `backend/app/schemas/driver.py::DriverBalanceRead`.
Map<String, dynamic> _balanceJson({
  int owedCents = 15000,
  int? balanceCapCents,
  List<Map<String, dynamic>> recentSettlements = const [],
}) => {
  'owed_cents': owedCents,
  'balance_cap_cents': balanceCapCents,
  'recent_settlements': recentSettlements,
};

/// `GET /v1/jobs/{id}` response shape (see `job_repository_test`-style
/// fixtures elsewhere) — the minimal valid `Job` shape.
Map<String, dynamic> _jobJson({
  String id = 'job-1',
  String status = 'matching',
  int quotedPrice = 50000,
}) => {
  'id': id,
  'customer_id': 'cust-1',
  'driver_id': null,
  'status': status,
  'vehicle_type': 'car',
  'pickup': {'lat': 6.2, 'lng': -75.5},
  'pickup_address': 'Origin',
  'dropoff': {'lat': 6.1, 'lng': -75.6},
  'dropoff_address': 'Destination',
  'distance_km': 5.0,
  'quoted_price': quotedPrice,
  'final_price': null,
  'payment_method': 'cash',
  'driver': null,
  'requested_at': '2026-01-01T00:00:00Z',
  'assigned_at': null,
  'picked_up_at': null,
  'completed_at': null,
  'cancelled_at': null,
  'cancel_reason': null,
  'share_token': null,
  'driver_commission': null,
};

Response<Map<String, dynamic>> _okResponse(
  Map<String, dynamic> data, {
  int statusCode = 200,
  String path = '/x',
}) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: statusCode,
  data: data,
);

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  late MockDio dio;
  late ApiDriversRepository repo;

  setUp(() {
    dio = MockDio();
    repo = ApiDriversRepository(dio);
  });

  group('ApiDriversRepository.registerDriver', () {
    test('posts the bring-your-own-truck fields and parses the nested truck',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _profileJson(truck: _truckJson()),
          statusCode: 201,
        ),
      );

      final profile = await repo.registerDriver(
        plate: 'XYZ987',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
        licenseUrl: 'https://example.com/license.png',
        truckPhotoUrl: 'https://example.com/truck.png',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/drivers/me/register');
      expect(captured[1], {
        'plate': 'XYZ987',
        'truck_type': 'car',
        'capacity': 'car',
        'license_url': 'https://example.com/license.png',
        'truck_photo_url': 'https://example.com/truck.png',
      });
      // Regression guard for the truck-shape bug this codebase already hit
      // once (truck info nested under `truck`, not flattened) -- confirms
      // the nested parse actually populates the plate/type/capacity.
      expect(profile.truck, isNotNull);
      expect(profile.truck!.plate, 'XYZ987');
      expect(profile.truck!.type, TruckType.car);
      expect(profile.truck!.capacity, TruckCapacity.car);
      expect(profile.verified, isFalse);
      expect(profile.status, DriverStatus.offline);
    });

    test('posts only invite_token when redeeming a fleet invite', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _profileJson(truck: _truckJson(plate: 'INV001')),
          statusCode: 201,
        ),
      );

      await repo.registerDriver(inviteToken: 'invite-token-1');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'invite_token': 'invite-token-1'});
    });

    test('propagates a 422 when both shapes are mixed', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/register'),
            statusCode: 422,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.registerDriver(
          plate: 'XYZ987',
          truckType: TruckType.car,
          capacity: TruckCapacity.car,
          inviteToken: 'invite-token-1',
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            422,
          ),
        ),
      );
    });

    test('propagates a 409 when already registered as a driver', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/register'),
            statusCode: 409,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.registerDriver(
          plate: 'XYZ987',
          truckType: TruckType.car,
          capacity: TruckCapacity.car,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiDriversRepository.setStatus', () {
    test('patches status + lat/lng when going available', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _profileJson(status: 'available', verified: true),
        ),
      );

      final profile = await repo.setStatus(
        DriverStatus.available,
        lat: 6.2442,
        lng: -75.5812,
      );

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/drivers/me/status');
      expect(captured[1], {
        'status': 'available',
        'lat': 6.2442,
        'lng': -75.5812,
      });
      expect(profile.status, DriverStatus.available);
    });

    test('omits lat/lng when going offline', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(_profileJson(status: 'offline')),
      );

      await repo.setStatus(DriverStatus.offline);

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'status': 'offline'});
    });

    test('parses the blocked status (ADM-2)', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(_profileJson(status: 'blocked')),
      );

      final profile = await repo.setStatus(DriverStatus.offline);

      expect(profile.status, DriverStatus.blocked);
    });

    test('propagates a 403 when unverified or blocked', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.setStatus(DriverStatus.available, lat: 0, lng: 0),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('propagates a 422 when going available without lat/lng', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
            statusCode: 422,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.setStatus(DriverStatus.available),
        throwsA(isA<DioException>()),
      );
    });

    test('propagates a 409 when mid-job (on_job)', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/status'),
            statusCode: 409,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.setStatus(DriverStatus.offline),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiDriversRepository.balance', () {
    test('gets /v1/drivers/me/balance and parses owed + settlements',
        () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _balanceJson(
            owedCents: 22500,
            balanceCapCents: 100000,
            recentSettlements: [
              {
                'id': 'settle-1',
                'amount_cents': 5000,
                'settled_at': '2026-01-01T00:00:00Z',
                'note': null,
              },
            ],
          ),
        ),
      );

      final balance = await repo.balance();

      verify(
        () => dio.get<Map<String, dynamic>>('/v1/drivers/me/balance'),
      ).called(1);
      expect(balance.owedCents, 22500);
      expect(balance.balanceCapCents, 100000);
      expect(balance.recentSettlements, hasLength(1));
      expect(balance.recentSettlements.single.amountCents, 5000);
    });

    test('parses a null balance_cap_cents (cap disabled)', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_balanceJson()),
      );

      final balance = await repo.balance();

      expect(balance.balanceCapCents, isNull);
      expect(balance.recentSettlements, isEmpty);
    });

    test('propagates a 404 when the driver has no profile', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/drivers/me/balance'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/drivers/me/balance'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(() => repo.balance(), throwsA(isA<DioException>()));
    });
  });

  group('ApiDriversRepository.incomingOffers', () {
    test('is an empty stream when no socket is wired', () async {
      await expectLater(repo.incomingOffers(), emitsDone);
    });

    test('fetches the job and maps a jobOffer push into a JobOffer',
        () async {
      final socket = MockCraneSocket();
      final controller = StreamController<ServerMessage>();
      when(() => socket.connect()).thenReturn(null);
      when(() => socket.messages).thenAnswer((_) => controller.stream);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-9', quotedPrice: 50000)),
      );

      final socketRepo = ApiDriversRepository(dio, socket);
      final offerFuture = socketRepo.incomingOffers().first;

      controller.add(
        const ServerMessage.jobOffer(
          jobId: 'job-9',
          offerId: 'offer-1',
          vehicleType: VehicleType.car,
          pickup: LatLng(lat: 6.2, lng: -75.5),
          dropoff: LatLng(lat: 6.1, lng: -75.6),
          quotedPrice: 50000,
          expiresInSeconds: 30,
          pickupDistanceKm: 3.2,
        ),
      );

      final offer = await offerFuture;
      verify(() => dio.get<Map<String, dynamic>>('/v1/jobs/job-9')).called(1);
      expect(offer.offerId, 'offer-1');
      expect(offer.job.id, 'job-9');
      expect(offer.pickupDistanceKm, 3.2);
      // 15% of the quoted price, rounded to the nearest 100 COP -- the
      // fallback approximation used when the backend didn't compute a real
      // commission (see ApiDriversRepository._toJobOffer).
      expect(offer.commissionAmount, 7500);

      await controller.close();
    });

    test('falls back to zero distance/commission when the backend omits them',
        () async {
      final socket = MockCraneSocket();
      final controller = StreamController<ServerMessage>();
      when(() => socket.connect()).thenReturn(null);
      when(() => socket.messages).thenAnswer((_) => controller.stream);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-10')),
      );

      final socketRepo = ApiDriversRepository(dio, socket);
      final offerFuture = socketRepo.incomingOffers().first;

      controller.add(
        const ServerMessage.jobOffer(
          jobId: 'job-10',
          offerId: 'offer-2',
          vehicleType: VehicleType.car,
          pickup: LatLng(lat: 6.2, lng: -75.5),
          dropoff: LatLng(lat: 6.1, lng: -75.6),
          expiresInSeconds: 30,
        ),
      );

      final offer = await offerFuture;
      expect(offer.pickupDistanceKm, 0);
      expect(offer.commissionAmount, 0);

      await controller.close();
    });
  });
}
