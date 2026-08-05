import 'package:dio/dio.dart';

import '../models/driver_profile.dart';
import '../models/job_offer.dart';

/// Driver-side operations (availability, incoming offers).
///
/// Implementations: [ApiDriversRepository] (dio → FastAPI) and
/// `FakeDriversRepository`. The composition root in `lib/app/di.dart`
/// picks one from `Env.useFakeBackend`.
abstract interface class DriversRepository {
  /// `PATCH /v1/drivers/me/status` — go available/offline.
  Future<DriverProfile> setStatus(DriverStatus status);

  /// Stream of dispatch offers for this driver.
  ///
  /// TODO(DSP-2/TRK-4): real offers arrive over the authed WebSocket (with an
  /// FCM tap-through when backgrounded). The dio implementation is empty
  /// until that lands; the fake exposes a dev trigger.
  Stream<JobOffer> incomingOffers();
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiDriversRepository implements DriversRepository {
  ApiDriversRepository(this._dio);

  final Dio _dio;

  @override
  Future<DriverProfile> setStatus(DriverStatus status) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/drivers/me/status',
      data: {'status': status.wire},
    );
    return DriverProfile.fromJson(res.data!);
  }

  @override
  Stream<JobOffer> incomingOffers() {
    // TODO(DSP-2/TRK-4): subscribe to `/v1/ws` and map offer events.
    return const Stream.empty();
  }
}
