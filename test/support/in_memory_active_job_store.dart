import 'package:the_crane/core/storage/active_job_store.dart';

/// CUS-4 test double: no `shared_preferences` platform channel needed.
class InMemoryActiveJobStore implements ActiveJobStore {
  String? _jobId;

  @override
  Future<String?> read() async => _jobId;

  @override
  Future<void> write(String? jobId) async {
    _jobId = jobId;
  }
}
