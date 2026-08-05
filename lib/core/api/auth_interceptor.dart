import 'package:dio/dio.dart';

/// Injects the Firebase ID token on every API request.
///
/// TODO(FND-1): once Firebase is wired (firebase_core + firebase_auth),
/// fetch the current user's ID token here and set
/// `options.headers['Authorization'] = 'Bearer <idToken>'`.
/// Until then this interceptor is a pass-through stub.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // TODO(FND-1): final token = await FirebaseAuth.instance.currentUser
    //   ?.getIdToken();
    // if (token != null) {
    //   options.headers['Authorization'] = 'Bearer $token';
    // }
    handler.next(options);
  }
}
