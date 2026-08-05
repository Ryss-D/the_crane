import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/api/api_client.dart';
import '../core/config/env.dart';

part 'providers.g.dart';

// TODO(FND-1): add firebase_core / firebase_auth / firebase_messaging
// providers here once the Firebase project is wired (needs native config
// files from the Firebase console).
// TODO(FND-6): add google_maps_flutter / location providers here once Maps
// keys and native setup are in place.

/// Dio HTTP client pointed at the FastAPI backend for the active flavor.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createDio(baseUrl: Env.apiBaseUrl);
