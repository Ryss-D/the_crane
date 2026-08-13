import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/truck.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/core/ws/server_message.dart';

class MockDio extends Mock implements Dio {}

class MockCraneSocket extends Mock implements CraneSocket {}

/// `GET/POST .../v1/jobs/...` response shape, per
/// `backend/app/schemas/job.py::JobRead`.
///
/// IMPORTANT: pickup/dropoff are flat `pickup_lat`/`pickup_lng`/
/// `dropoff_lat`/`dropoff_lng` fields on the wire -- never a nested
/// `{"pickup": {"lat":.., "lng":..}}` object. That nested shape is only
/// `JobCreate`'s own `LocationIn`, used on the way *in*; the backend never
/// mirrors it on the way back out. `ApiJobsRepository`'s private
/// `_reshapeJobJson` exists to bridge exactly this gap -- these fixtures
/// intentionally mirror the real (flat) backend shape, not the client's
/// internal (nested) `Job.pickup`/`Job.dropoff`, so a regression there is
/// actually caught.
Map<String, dynamic> _jobJson({
  String id = 'job-1',
  String? driverId,
  String status = 'matching',
  String vehicleType = 'car',
  double pickupLat = 6.2088,
  double pickupLng = -75.5679,
  double dropoffLat = 6.1450,
  double dropoffLng = -75.6169,
  int? quotedPrice = 120000,
  int? finalPrice,
  int? driverCommission,
  Map<String, dynamic>? driver,
  String? shareToken = 'tok-1',
}) => {
  'id': id,
  'customer_id': 'cus-1',
  'driver_id': driverId,
  'driver': driver,
  'vehicle_type': vehicleType,
  'status': status,
  'pickup_lat': pickupLat,
  'pickup_lng': pickupLng,
  'dropoff_lat': dropoffLat,
  'dropoff_lng': dropoffLng,
  'pickup_address': 'Origin',
  'dropoff_address': 'Destination',
  'distance_km': 5.4,
  'quoted_price': quotedPrice,
  'final_price': finalPrice,
  'payment_method': 'cash',
  'config_snapshot': null,
  'requested_at': '2026-01-01T00:00:00Z',
  'assigned_at': null,
  'picked_up_at': null,
  'completed_at': null,
  'cancelled_at': null,
  'cancel_reason': null,
  'share_token': shareToken,
  'driver_commission': driverCommission,
};

/// `JobDriverInfo` shape nested under `JobRead.driver`.
Map<String, dynamic> _driverInfoJson({
  String id = 'drv-1',
  String? name = 'Carlos Ramírez',
  String? phone = '+573001112233',
  String truckPlate = 'TGX123',
  String truckType = 'flatbed',
  double? ratingAvg = 4.8,
}) => {
  'id': id,
  'name': name,
  'phone': phone,
  'truck_plate': truckPlate,
  'truck_type': truckType,
  'rating_avg': ratingAvg,
  'photo_url': null,
};

/// `RatingRead` shape, per `backend/app/schemas/rating.py`.
Map<String, dynamic> _ratingJson({
  String id = 'rat-1',
  String jobId = 'job-14',
  String fromUserId = 'cus-1',
  String toUserId = 'drv-1',
  int stars = 5,
  String? comment,
}) => {
  'id': id,
  'job_id': jobId,
  'from_user_id': fromUserId,
  'to_user_id': toUserId,
  'stars': stars,
  'comment': comment,
  'created_at': '2026-01-01T00:00:00Z',
};

Response<T> _okResponse<T>(
  T data, {
  int statusCode = 200,
  String path = '/x',
}) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: statusCode,
  data: data,
);

DioException _dioError(int statusCode, {String path = '/x', Object? data}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  late MockDio dio;
  late ApiJobsRepository repo;

  setUp(() {
    dio = MockDio();
    repo = ApiJobsRepository(dio);
  });

  group('ApiJobsRepository.requestQuote', () {
    test(
        'posts pickup/dropoff/vehicle_type and derives an absolute expiresAt '
        'from the relative expires_in_seconds', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse({
          'quote_id': 'q-1',
          'vehicle_type': 'car',
          'price': 95000,
          'distance_km': 8.2,
          'eta_minutes': 12,
          'expires_in_seconds': 600,
        }),
      );

      final before = DateTime.now();
      final quote = await repo.requestQuote(
        pickup: const LatLng(lat: 6.2442, lng: -75.5812),
        dropoff: const LatLng(lat: 6.1, lng: -75.6),
        vehicleType: VehicleType.car,
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/jobs/quote');
      expect(captured[1], {
        'pickup': {'lat': 6.2442, 'lng': -75.5812},
        'dropoff': {'lat': 6.1, 'lng': -75.6},
        'vehicle_type': 'car',
      });
      expect(quote.quoteId, 'q-1');
      expect(quote.price, 95000);
      expect(quote.expiresAt, isNotNull);
      // The real backend (`QuoteResponse`) never sends an absolute
      // `expires_at` -- only the relative `expires_in_seconds` -- so this
      // conversion is the only thing that gives the stale-quote refresh
      // timer (`RequestBloc`) a real deadline.
      expect(quote.expiresAt!.difference(before).inSeconds, closeTo(600, 2));
    });

    test('leaves expiresAt null when the backend omits expires_in_seconds',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse({
          'quote_id': 'q-2',
          'vehicle_type': 'car',
          'price': 95000,
          'distance_km': 8.2,
          'eta_minutes': 12,
        }),
      );

      final quote = await repo.requestQuote(
        pickup: const LatLng(lat: 6.2, lng: -75.5),
        dropoff: const LatLng(lat: 6.1, lng: -75.6),
        vehicleType: VehicleType.car,
      );

      expect(quote.expiresAt, isNull);
    });
  });

  group('ApiJobsRepository.createJob', () {
    test(
        'posts the full JobCreate shape: vehicle_type + nested '
        'pickup/dropoff{lat,lng,address}', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-9'), statusCode: 201),
      );

      final job = await repo.createJob(
        quoteId: 'q-1',
        vehicleType: VehicleType.car,
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        pickupAddress: 'Origin',
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
        dropoffAddress: 'Destination',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/jobs');
      // Regression guard: the backend's `JobCreate`
      // (`backend/app/schemas/job.py`) requires `vehicle_type` plus nested
      // `pickup`/`dropoff` (`LocationIn`: lat/lng/address) -- this client
      // used to send only `quote_id`/`pickup_address`/`dropoff_address`,
      // which 422s against the real backend since the quote cache
      // (`app/services/pricing.py`) never round-trips the coordinates.
      expect(captured[1], {
        'quote_id': 'q-1',
        'vehicle_type': 'car',
        'pickup': {'lat': 6.2088, 'lng': -75.5679, 'address': 'Origin'},
        'dropoff': {'lat': 6.1450, 'lng': -75.6169, 'address': 'Destination'},
      });
      expect(job.id, 'job-9');
      expect(job.status, JobStatus.matching);
    });

    test(
        'parses the flat pickup_lat/pickup_lng response into a nested '
        'LatLng', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse(
          _jobJson(
            pickupLat: 6.11,
            pickupLng: -75.11,
            dropoffLat: 6.22,
            dropoffLng: -75.22,
          ),
          statusCode: 201,
        ),
      );

      final job = await repo.createJob(
        quoteId: 'q-1',
        vehicleType: VehicleType.car,
        pickup: const LatLng(lat: 6.2088, lng: -75.5679),
        pickupAddress: 'Origin',
        dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
        dropoffAddress: 'Destination',
      );

      // Regression guard: `JobRead` serializes flat pickup_lat/pickup_lng/
      // dropoff_lat/dropoff_lng, never a nested `{"pickup": {...}}` object
      // -- parsing the raw response with `Job.fromJson` alone throws a
      // null-cast against that real shape.
      expect(job.pickup, const LatLng(lat: 6.11, lng: -75.11));
      expect(job.dropoff, const LatLng(lat: 6.22, lng: -75.22));
    });

    test('propagates a 410 when the quote is expired or unknown', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(410, path: '/v1/jobs'));

      expect(
        () => repo.createJob(
          quoteId: 'q-expired',
          vehicleType: VehicleType.car,
          pickup: const LatLng(lat: 6.2, lng: -75.5),
          pickupAddress: 'Origin',
          dropoff: const LatLng(lat: 6.1, lng: -75.6),
          dropoffAddress: 'Destination',
        ),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'statusCode', 410),
        ),
      );
    });
  });

  group('ApiJobsRepository.getJob', () {
    test('gets /v1/jobs/{id} and parses the nested driver summary',
        () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _jobJson(
            id: 'job-5',
            status: 'assigned',
            driverId: 'drv-1',
            driver: _driverInfoJson(),
          ),
        ),
      );

      final job = await repo.getJob('job-5');

      verify(() => dio.get<Map<String, dynamic>>('/v1/jobs/job-5')).called(1);
      expect(job.status, JobStatus.assigned);
      expect(job.driverId, 'drv-1');
      expect(job.driver, isNotNull);
      expect(job.driver!.name, 'Carlos Ramírez');
      expect(job.driver!.truckType, TruckType.flatbed);
      expect(job.driver!.ratingAvg, 4.8);
    });

    test('parses a job with no driver yet as null', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-6', status: 'matching')),
      );

      final job = await repo.getJob('job-6');

      expect(job.driver, isNull);
      expect(job.driverId, isNull);
    });

    test('propagates a 404 for an unknown job', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(404, path: '/v1/jobs/nope'));

      expect(() => repo.getJob('nope'), throwsA(isA<DioException>()));
    });
  });

  group('ApiJobsRepository.watchJob (no socket)', () {
    test('emits the current snapshot without a socket wired', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-1', status: 'matching')),
      );

      final job = await repo.watchJob('job-1').first;

      expect(job.id, 'job-1');
      expect(job.status, JobStatus.matching);
    });
  });

  group('ApiJobsRepository.watchJob (via socket, TRK-4)', () {
    late MockCraneSocket socket;
    late ApiJobsRepository socketRepo;
    late StreamController<CraneSocketStatus> statusController;
    late StreamController<ServerMessage> messageController;

    setUp(() {
      socket = MockCraneSocket();
      socketRepo = ApiJobsRepository(dio, socket);
      statusController = StreamController<CraneSocketStatus>.broadcast();
      messageController = StreamController<ServerMessage>.broadcast();
      when(() => socket.connect()).thenReturn(null);
      when(() => socket.subscribe(any())).thenReturn(null);
      when(() => socket.unsubscribe(any())).thenReturn(null);
      when(() => socket.statusStream)
          .thenAnswer((_) => statusController.stream);
      when(() => socket.messages).thenAnswer((_) => messageController.stream);
    });

    tearDown(() async {
      await statusController.close();
      await messageController.close();
    });

    test(
        'connects, subscribes, and emits an immediate snapshot when already '
        'connected', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-2', status: 'assigned')),
      );

      final job = await socketRepo.watchJob('job-2').first;

      verify(() => socket.connect()).called(1);
      verify(() => socket.subscribe('job-2')).called(1);
      expect(job.status, JobStatus.assigned);
    });

    test('falls back to polling while the socket is disconnected', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.disconnected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-3', status: 'matching')),
      );

      // One immediate snapshot from `onListen`'s own `emitSnapshot`, plus
      // one from `_pollJob`'s first (no-delay) iteration -- both fire well
      // before the real 3s poll interval, so this doesn't need to wait it
      // out.
      final values = await socketRepo.watchJob('job-3').take(2).toList();

      expect(values, hasLength(2));
      expect(values.every((j) => j.status == JobStatus.matching), isTrue);
      verify(() => dio.get<Map<String, dynamic>>('/v1/jobs/job-3'))
          .called(greaterThanOrEqualTo(2));
    });

    test(
        'stops polling and re-emits a snapshot once the status stream '
        'reports reconnected', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.disconnected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-17', status: 'matching')),
      );

      final seen = <Job>[];
      final sub = socketRepo.watchJob('job-17').listen(seen.add);
      // Let the disconnected-path snapshot(s) land first.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(seen, isNotEmpty);

      statusController.add(CraneSocketStatus.connected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The reconnect handler's own `emitSnapshot()` call landed on top of
      // whatever the disconnected-path polling already emitted.
      expect(seen.length, greaterThanOrEqualTo(2));
      await sub.cancel();
    });

    test(
        'starts polling when the status stream reports a drop while '
        'already connected', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-19', status: 'matching')),
      );

      final seen = <Job>[];
      final sub = socketRepo.watchJob('job-19').listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final afterConnect = seen.length;
      expect(afterConnect, greaterThanOrEqualTo(1));

      // The socket drops -- the status listener's `else` branch falls back
      // to polling so the stream doesn't go silent until it reconnects.
      statusController.add(CraneSocketStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(seen.length, greaterThan(afterConnect));
      await sub.cancel();
    });

    test('re-fetches when a job_event for this job id arrives', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      var callCount = 0;
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async {
        callCount++;
        return _okResponse(
          _jobJson(id: 'job-4', status: callCount == 1 ? 'matching' : 'assigned'),
        );
      });

      final seen = <JobStatus>[];
      final sub = socketRepo.watchJob('job-4').listen((job) => seen.add(job.status));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(callCount, 1);

      messageController.add(
        const ServerMessage.jobEvent(jobId: 'job-4', status: 'assigned'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(callCount, 2);
      expect(seen, [JobStatus.matching, JobStatus.assigned]);
      await sub.cancel();
    });

    test('ignores a job_event for a different job id', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-5')),
      );

      final sub = socketRepo.watchJob('job-5').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      messageController.add(
        const ServerMessage.jobEvent(jobId: 'some-other-job', status: 'assigned'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => dio.get<Map<String, dynamic>>('/v1/jobs/job-5')).called(1);
      await sub.cancel();
    });

    test(
        'surfaces a getJob failure as a stream error rather than crashing '
        'the listener', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(500, path: '/v1/jobs/job-18'));

      final errors = <Object>[];
      final sub = socketRepo
          .watchJob('job-18')
          .listen((_) {}, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(errors, hasLength(1));
      expect(errors.single, isA<DioException>());
      await sub.cancel();
    });

    test('unsubscribes from the socket when the listener cancels', () async {
      when(() => socket.status).thenReturn(CraneSocketStatus.connected);
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-6')),
      );

      final sub = socketRepo.watchJob('job-6').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      verify(() => socket.unsubscribe('job-6')).called(1);
    });
  });

  group('ApiJobsRepository.acceptJob', () {
    test('posts /accept and parses the assigned job', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer(
        (_) async =>
            _okResponse(_jobJson(id: 'job-7', status: 'assigned', driverId: 'drv-1')),
      );

      final job = await repo.acceptJob('job-7');

      verify(() => dio.post<Map<String, dynamic>>('/v1/jobs/job-7/accept'))
          .called(1);
      expect(job.status, JobStatus.assigned);
      expect(job.driverId, 'drv-1');
    });

    test('propagates a 409 when the offer already expired or was claimed',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(409, path: '/v1/jobs/job-7/accept'));

      expect(() => repo.acceptJob('job-7'), throwsA(isA<DioException>()));
    });
  });

  group('ApiJobsRepository.cancelJob', () {
    test('posts /cancel (ignoring asDriver) and parses the cancelled job',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_jobJson(id: 'job-8', status: 'cancelled')),
      );

      final job = await repo.cancelJob('job-8', asDriver: true);

      verify(() => dio.post<Map<String, dynamic>>('/v1/jobs/job-8/cancel'))
          .called(1);
      expect(job.status, JobStatus.cancelled);
    });

    test(
        'maps a 403 into JobStatusRejectedException carrying the backend '
        'detail verbatim', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(
          403,
          path: '/v1/jobs/job-8/cancel',
          data: {
            'detail': 'Only the customer or assigned driver may cancel this job',
          },
        ),
      );

      await expectLater(
        () => repo.cancelJob('job-8'),
        throwsA(
          isA<JobStatusRejectedException>().having(
            (e) => e.message,
            'message',
            'Only the customer or assigned driver may cancel this job',
          ),
        ),
      );
    });

    test('maps a 409 into JobStatusRejectedException (past the grace window)',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(
          409,
          path: '/v1/jobs/job-8/cancel',
          data: {'detail': 'Job can no longer be cancelled'},
        ),
      );

      await expectLater(
        () => repo.cancelJob('job-8'),
        throwsA(isA<JobStatusRejectedException>()),
      );
    });

    test('falls back to a generic message when the backend sends no detail',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(403, path: '/v1/jobs/job-8/cancel'));

      await expectLater(
        () => repo.cancelJob('job-8'),
        throwsA(
          isA<JobStatusRejectedException>()
              .having((e) => e.message, 'message', 'Cancel rejected'),
        ),
      );
    });

    test('rethrows a plain DioException for other status codes (e.g. 404)',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(404, path: '/v1/jobs/job-8/cancel'));

      expect(
        () => repo.cancelJob('job-8'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('ApiJobsRepository.updateJobStatus', () {
    test('posts the wire status value and parses the advanced job',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            _okResponse(_jobJson(id: 'job-11', status: 'en_route_pickup')),
      );

      final job =
          await repo.updateJobStatus('job-11', JobStatus.enRoutePickup);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/jobs/job-11/status');
      expect(captured[1], {'status': 'en_route_pickup'});
      expect(job.status, JobStatus.enRoutePickup);
    });

    test(
        'maps a 403 into JobStatusRejectedException (e.g. completing via '
        'this endpoint)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        _dioError(
          403,
          path: '/v1/jobs/job-11/status',
          data: {
            'detail': 'Completion is confirmed by the customer (confirm-delivery)',
          },
        ),
      );

      await expectLater(
        () => repo.updateJobStatus('job-11', JobStatus.completed),
        throwsA(
          isA<JobStatusRejectedException>().having(
            (e) => e.message,
            'message',
            'Completion is confirmed by the customer (confirm-delivery)',
          ),
        ),
      );
    });

    test('maps a 409 into JobStatusRejectedException (out-of-order transition)',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        _dioError(
          409,
          path: '/v1/jobs/job-11/status',
          data: {'detail': 'Drivers cannot set status loading'},
        ),
      );

      await expectLater(
        () => repo.updateJobStatus('job-11', JobStatus.loading),
        throwsA(isA<JobStatusRejectedException>()),
      );
    });

    test('rethrows a plain DioException for other status codes', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(500, path: '/v1/jobs/job-11/status'));

      expect(
        () => repo.updateJobStatus('job-11', JobStatus.loading),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiJobsRepository.confirmDelivery', () {
    test('posts /confirm-delivery and parses the completed job + commission',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _jobJson(id: 'job-12', status: 'completed', driverCommission: 18000),
        ),
      );

      final job = await repo.confirmDelivery('job-12');

      verify(
        () => dio.post<Map<String, dynamic>>('/v1/jobs/job-12/confirm-delivery'),
      ).called(1);
      expect(job.status, JobStatus.completed);
      expect(job.driverCommission, 18000);
    });

    test('propagates a 403 when the caller is not the job\'s customer',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(403, path: '/v1/jobs/job-12/confirm-delivery'),
      );

      expect(
        () => repo.confirmDelivery('job-12'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiJobsRepository.submitRating', () {
    test('posts stars + a trimmed comment', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _okResponse<void>(null, statusCode: 201));

      await repo.submitRating('job-13', stars: 5, comment: '  Great service!  ');

      final captured = verify(
        () => dio.post<void>(captureAny(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured[0], '/v1/jobs/job-13/rating');
      expect(captured[1], {'stars': 5, 'comment': 'Great service!'});
    });

    test('omits comment when null', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _okResponse<void>(null, statusCode: 201));

      await repo.submitRating('job-13', stars: 4);

      final captured = verify(
        () => dio.post<void>(any(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured.single, {'stars': 4});
    });

    test('omits comment when blank after trimming', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _okResponse<void>(null, statusCode: 201));

      await repo.submitRating('job-13', stars: 3, comment: '   ');

      final captured = verify(
        () => dio.post<void>(any(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured.single, {'stars': 3});
    });

    test('propagates a 409 when this side already rated the job', () async {
      when(() => dio.post<void>(any(), data: any(named: 'data')))
          .thenThrow(_dioError(409, path: '/v1/jobs/job-13/rating'));

      expect(
        () => repo.submitRating('job-13', stars: 5),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiJobsRepository.getRatings', () {
    test('parses the {"items": [...]} envelope the real backend sends',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => _okResponse<dynamic>({'items': [_ratingJson()]}),
      );

      final ratings = await repo.getRatings('job-14');

      verify(() => dio.get<dynamic>('/v1/jobs/job-14/ratings')).called(1);
      expect(ratings, hasLength(1));
      expect(ratings.single.stars, 5);
      expect(ratings.single.fromUserId, 'cus-1');
    });

    test('also accepts a bare JSON array defensively', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => _okResponse<dynamic>([_ratingJson(id: 'rat-2')]),
      );

      final ratings = await repo.getRatings('job-14');

      expect(ratings.single.id, 'rat-2');
    });

    test('returns an empty list when there are no ratings yet', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => _okResponse<dynamic>({'items': <dynamic>[]}),
      );

      final ratings = await repo.getRatings('job-14');

      expect(ratings, isEmpty);
    });
  });

  group('ApiJobsRepository.listHistory', () {
    test('sends role/limit/offset query params and parses the page',
        () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _okResponse({
          'items': [
            _jobJson(id: 'job-15', status: 'completed'),
            _jobJson(id: 'job-16', status: 'cancelled'),
          ],
          'total': 2,
          'limit': 20,
          'offset': 0,
        }),
      );

      final page = await repo.listHistory(
        role: JobHistoryRole.driver,
        limit: 20,
        offset: 0,
      );

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured[0], '/v1/jobs');
      expect(captured[1], {'role': 'driver', 'limit': 20, 'offset': 0});
      expect(page.total, 2);
      expect(page.items, hasLength(2));
      // Each history item goes through the same flat -> nested pickup/
      // dropoff reshape as every other job-returning endpoint.
      expect(page.items[0].id, 'job-15');
      expect(page.items[0].pickup, isA<LatLng>());
      expect(page.items[1].status, JobStatus.cancelled);
    });

    test('defaults to role=customer, limit=20, offset=0', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          {'items': <dynamic>[], 'total': 0, 'limit': 20, 'offset': 0},
        ),
      );

      await repo.listHistory(role: JobHistoryRole.customer);

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured.single, {'role': 'customer', 'limit': 20, 'offset': 0});
    });

    test('returns an empty page when the caller has no history', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          {'items': <dynamic>[], 'total': 0, 'limit': 20, 'offset': 0},
        ),
      );

      final page = await repo.listHistory(role: JobHistoryRole.customer);

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });
  });
}
