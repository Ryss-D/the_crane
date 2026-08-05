import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/drivers_repository.dart';
import '../core/api/fake_drivers_repository.dart';
import '../core/api/fake_jobs_repository.dart';
import '../core/api/jobs_repository.dart';
import '../core/config/env.dart';

// TODO(FND-1): construct firebase_core / firebase_auth / firebase_messaging
// instances here once the Firebase project is wired (needs native config
// files from the Firebase console).
// TODO(FND-6): construct google_maps / location services here once Maps
// keys and native setup are in place.

/// Composition root: builds the HTTP client and repositories once at app
/// start. The instances are exposed to the widget tree through
/// `MultiRepositoryProvider` in `main.dart`.
class AppDependencies {
  AppDependencies({
    required this.dio,
    required this.jobsRepository,
    required this.driversRepository,
  });

  /// Production wiring for the active flavor.
  ///
  /// [Env.useFakeBackend] (default true) selects seeded in-memory fakes;
  /// once the FastAPI backend is reachable, set `USE_FAKE_BACKEND=false` in
  /// the flavor env file and the dio implementations take over — no code
  /// changes. The fake drivers repo shares the fake jobs repo so a
  /// dev-triggered offer can be accepted end to end.
  factory AppDependencies.fromEnv() {
    final dio = createDio(baseUrl: Env.apiBaseUrl);
    if (Env.useFakeBackend) {
      final jobs = FakeJobsRepository();
      return AppDependencies(
        dio: dio,
        jobsRepository: jobs,
        driversRepository: FakeDriversRepository(jobs: jobs),
      );
    }
    return AppDependencies(
      dio: dio,
      jobsRepository: ApiJobsRepository(dio),
      driversRepository: ApiDriversRepository(dio),
    );
  }

  final Dio dio;
  final JobsRepository jobsRepository;
  final DriversRepository driversRepository;
}
