import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Injects the current Firebase user's ID token on every API request.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
