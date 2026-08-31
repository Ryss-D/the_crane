import 'package:shared_preferences/shared_preferences.dart';

/// CUS-4: persists which job (if any) the customer is currently watching,
/// so [RequestBloc] can resume the matching/tracking screen after the app
/// is force-quit and reopened instead of losing an in-progress job
/// entirely. Deliberately just an id, not the job itself — [RequestBloc]
/// always re-fetches the real thing (`JobsRepository.getJob`) rather than
/// trusting a possibly-stale cached snapshot.
abstract class ActiveJobStore {
  /// The persisted job id, or null if there isn't one (never started, or
  /// already cleared).
  Future<String?> read();

  /// Persists [jobId] as the one to resume on next launch; pass null to
  /// clear it (the job reached a terminal status, or the customer left the
  /// flow before one existed).
  Future<void> write(String? jobId);
}

/// Disk-backed via `shared_preferences` — this app's only persistence need
/// so far, so a single string key rather than a bigger dependency
/// (`sqflite`/`hive`).
class SharedPreferencesActiveJobStore implements ActiveJobStore {
  SharedPreferencesActiveJobStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'active_customer_job_id';

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String? jobId) async {
    if (jobId == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jobId);
    }
  }
}
