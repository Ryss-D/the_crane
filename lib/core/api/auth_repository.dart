import 'package:dio/dio.dart';

import '../models/app_user.dart';

/// Backend profile operations post-Firebase-sign-in: `POST /v1/auth/sync`
/// (idempotent create-or-fetch) and `PATCH /v1/me` (profile completion).
abstract interface class AuthRepository {
  /// Creates the backend user row on first sign-in, or returns the existing
  /// one. `name` is optional — phone auth alone gives the backend no name,
  /// so a fresh signup comes back with `name: null` until profile
  /// completion calls [updateProfile].
  Future<AppUser> sync({String? name});

  Future<AppUser> updateProfile({required String name});
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AppUser> sync({String? name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/sync',
      // ignore: use_null_aware_elements
      data: {if (name != null) 'name': name},
    );
    return AppUser.fromJson(res.data!);
  }

  @override
  Future<AppUser> updateProfile({required String name}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/me',
      data: {'name': name},
    );
    return AppUser.fromJson(res.data!);
  }
}
