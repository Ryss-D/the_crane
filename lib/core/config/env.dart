/// Compile-time environment configuration.
///
/// Values are injected per flavor with `--dart-define-from-file`:
///
/// ```sh
/// flutter run --dart-define-from-file=env/dev.json
/// flutter run --dart-define-from-file=env/prod.json
/// ```
abstract final class Env {
  /// Base URL of the FastAPI backend (no trailing slash).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Flavor name: `dev` or `prod`.
  static const String name = String.fromEnvironment('ENV', defaultValue: 'dev');

  /// When true, repositories are backed by in-memory fakes with seeded data
  /// instead of the FastAPI backend.
  ///
  /// Defaults to true until the backend is reachable; flip per flavor with
  /// `USE_FAKE_BACKEND=false` in `env/*.json` once FND-1 (Firebase auth) and
  /// the jobs API are deployed.
  static const bool useFakeBackend = bool.fromEnvironment(
    'USE_FAKE_BACKEND',
    defaultValue: true,
  );

  static const bool isProd = name == 'prod';
  static const bool isDev = !isProd;
}
