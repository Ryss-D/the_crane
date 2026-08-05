import 'package:the_crane/app/di.dart';
import 'package:the_crane/core/api/api_client.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';

/// Fast fake jobs repo for tests (delays measured in a few ms so widget
/// tests can pump them deterministically).
FakeJobsRepository fastFakeJobs({
  Duration matchingDelay = const Duration(milliseconds: 300),
  FakeMatchingOutcome matchingOutcome = FakeMatchingOutcome.assigned,
}) {
  return FakeJobsRepository(
    quoteDelay: const Duration(milliseconds: 20),
    createDelay: const Duration(milliseconds: 20),
    actionDelay: const Duration(milliseconds: 10),
    matchingDelay: matchingDelay,
    matchingOutcome: matchingOutcome,
  );
}

/// Composition root for tests: fake repositories with short delays.
AppDependencies testDependencies({
  FakeJobsRepository? jobs,
  FakeDriversRepository? drivers,
}) {
  final jobsRepository = jobs ?? fastFakeJobs();
  return AppDependencies(
    dio: createDio(baseUrl: 'http://localhost:8000'),
    jobsRepository: jobsRepository,
    driversRepository: drivers ??
        FakeDriversRepository(
          jobs: jobsRepository,
          actionDelay: const Duration(milliseconds: 20),
        ),
  );
}
