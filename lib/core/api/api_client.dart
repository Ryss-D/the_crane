import 'package:dio/dio.dart';

import 'auth_interceptor.dart';

/// Builds the configured [Dio] instance used for all REST calls.
///
/// Exposed to the widget tree via `dioProvider` in `lib/app/providers.dart`.
Dio createDio({required String baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor());
  return dio;
}
