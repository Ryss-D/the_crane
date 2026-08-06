import 'package:dio/dio.dart';

import '../models/job.dart';
import '../models/saved_vehicle.dart';

/// CUS-6 — CRUD for a customer's saved vehicles, speeding up repeat
/// requests (a saved vehicle preselects its type in the CUS-2 quote step).
///
/// Implementations: [ApiVehiclesRepository] (dio → FastAPI) and
/// `FakeVehiclesRepository`. The composition root in `lib/app/di.dart`
/// picks one from `Env.useFakeBackend`. The backend team builds the
/// `/v1/me/vehicles` endpoints in parallel — this client matches their
/// documented contract exactly, but is built and tested against the fake
/// regardless of whether the real endpoints are live yet.
abstract interface class VehiclesRepository {
  /// `GET /v1/me/vehicles`.
  Future<List<SavedVehicle>> listVehicles();

  /// `POST /v1/me/vehicles` -> 201.
  Future<SavedVehicle> createVehicle({
    required VehicleType type,
    String? make,
    String? model,
    required String plate,
  });

  /// `PATCH /v1/me/vehicles/{id}` — any subset of the fields may be passed;
  /// omitted ones are left unchanged.
  Future<SavedVehicle> updateVehicle(
    String id, {
    VehicleType? type,
    String? make,
    String? model,
    String? plate,
  });

  /// `DELETE /v1/me/vehicles/{id}` -> 204.
  Future<void> deleteVehicle(String id);
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiVehiclesRepository implements VehiclesRepository {
  ApiVehiclesRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<SavedVehicle>> listVehicles() async {
    final res = await _dio.get<List<dynamic>>('/v1/me/vehicles');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SavedVehicle.fromJson)
        .toList(growable: false);
  }

  @override
  Future<SavedVehicle> createVehicle({
    required VehicleType type,
    String? make,
    String? model,
    required String plate,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/me/vehicles',
      data: {
        'type': type.wire,
        // ignore: use_null_aware_elements
        if (make != null) 'make': make,
        // ignore: use_null_aware_elements
        if (model != null) 'model': model,
        'plate': plate,
      },
    );
    return SavedVehicle.fromJson(res.data!);
  }

  @override
  Future<SavedVehicle> updateVehicle(
    String id, {
    VehicleType? type,
    String? make,
    String? model,
    String? plate,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/me/vehicles/$id',
      data: {
        // ignore: use_null_aware_elements
        if (type != null) 'type': type.wire,
        // ignore: use_null_aware_elements
        if (make != null) 'make': make,
        // ignore: use_null_aware_elements
        if (model != null) 'model': model,
        // ignore: use_null_aware_elements
        if (plate != null) 'plate': plate,
      },
    );
    return SavedVehicle.fromJson(res.data!);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await _dio.delete<void>('/v1/me/vehicles/$id');
  }
}
