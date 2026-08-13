import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/core/api/vehicles_repository.dart';
import 'package:the_crane/core/models/job.dart';

class MockDio extends Mock implements Dio {}

/// `GET/POST/PATCH /v1/me/vehicles` item shape, per
/// `backend/app/schemas/vehicle.py::VehicleRead`. `created_at` is included
/// to match the real backend exactly even though [SavedVehicle] doesn't
/// model it (json_serializable silently ignores unknown keys).
Map<String, dynamic> _vehicleJson({
  String id = 'veh-1',
  String type = 'car',
  String? make,
  String? model,
  String? plate = 'ABC123',
}) => {
  'id': id,
  'type': type,
  'make': make,
  'model': model,
  'plate': plate,
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

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  late MockDio dio;
  late ApiVehiclesRepository repo;

  setUp(() {
    dio = MockDio();
    repo = ApiVehiclesRepository(dio);
  });

  group('ApiVehiclesRepository.listVehicles', () {
    test('gets /v1/me/vehicles and parses the list', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => _okResponse<List<dynamic>>([
          _vehicleJson(id: 'veh-1', plate: 'AAA111'),
          _vehicleJson(id: 'veh-2', type: 'suv', plate: 'BBB222'),
        ]),
      );

      final vehicles = await repo.listVehicles();

      verify(() => dio.get<List<dynamic>>('/v1/me/vehicles')).called(1);
      expect(vehicles, hasLength(2));
      expect(vehicles[0].id, 'veh-1');
      expect(vehicles[0].plate, 'AAA111');
      expect(vehicles[1].type, VehicleType.suv);
    });

    test('returns an empty list when the backend has none', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => _okResponse<List<dynamic>>(<dynamic>[]),
      );

      final vehicles = await repo.listVehicles();

      expect(vehicles, isEmpty);
    });

    test('propagates a DioException', () async {
      when(() => dio.get<List<dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/me/vehicles'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/me/vehicles'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(() => repo.listVehicles(), throwsA(isA<DioException>()));
    });
  });

  group('ApiVehiclesRepository.createVehicle', () {
    test('posts the full body and parses the created vehicle', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _vehicleJson(
            id: 'veh-3',
            type: 'suv',
            make: 'Toyota',
            model: 'Fortuner',
            plate: 'SUV001',
          ),
          statusCode: 201,
        ),
      );

      final vehicle = await repo.createVehicle(
        type: VehicleType.suv,
        make: 'Toyota',
        model: 'Fortuner',
        plate: 'SUV001',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/me/vehicles');
      expect(captured[1], {
        'type': 'suv',
        'make': 'Toyota',
        'model': 'Fortuner',
        'plate': 'SUV001',
      });
      expect(vehicle.id, 'veh-3');
      expect(vehicle.type, VehicleType.suv);
    });

    test('omits make/model when not passed', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _vehicleJson(id: 'veh-4', make: null, model: null, plate: 'PLN001'),
          statusCode: 201,
        ),
      );

      await repo.createVehicle(type: VehicleType.car, plate: 'PLN001');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'type': 'car', 'plate': 'PLN001'});
    });

    test('propagates a 422 DioException', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/me/vehicles'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/me/vehicles'),
            statusCode: 422,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.createVehicle(type: VehicleType.car, plate: 'X'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiVehiclesRepository.updateVehicle', () {
    test('patches only the given fields', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _vehicleJson(id: 'veh-1', plate: 'NEWPLT'),
        ),
      );

      final vehicle = await repo.updateVehicle('veh-1', plate: 'NEWPLT');

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/me/vehicles/veh-1');
      expect(captured[1], {'plate': 'NEWPLT'});
      expect(vehicle.plate, 'NEWPLT');
    });

    test('sends every field when all are passed', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(
          _vehicleJson(
            id: 'veh-1',
            type: 'moto',
            make: 'Yamaha',
            model: 'FZ',
            plate: 'MOT001',
          ),
        ),
      );

      await repo.updateVehicle(
        'veh-1',
        type: VehicleType.moto,
        make: 'Yamaha',
        model: 'FZ',
        plate: 'MOT001',
      );

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {
        'type': 'moto',
        'make': 'Yamaha',
        'model': 'FZ',
        'plate': 'MOT001',
      });
    });

    test('propagates a 404 DioException for an unknown id', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/me/vehicles/unknown'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/me/vehicles/unknown'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.updateVehicle('unknown', plate: 'X'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  group('ApiVehiclesRepository.deleteVehicle', () {
    test('deletes by id', () async {
      when(() => dio.delete<void>(any())).thenAnswer(
        (_) async => _okResponse<void>(null, statusCode: 204),
      );

      await repo.deleteVehicle('veh-1');

      verify(() => dio.delete<void>('/v1/me/vehicles/veh-1')).called(1);
    });

    test('propagates a 404 DioException for an unknown id', () async {
      when(() => dio.delete<void>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/me/vehicles/unknown'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/me/vehicles/unknown'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.deleteVehicle('unknown'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
