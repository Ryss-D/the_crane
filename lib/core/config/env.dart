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

  /// Base URL of `web-client` (no trailing slash) — used to build the
  /// `/t/{token}` share-trip link (CUS-4/TRK-6). Defaults to its local dev
  /// server; update per flavor once WEB-5 picks a real deploy target.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'http://localhost:5173',
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

  /// OPS-6: Sentry DSN for crash/error reporting. Empty string (the default when
  /// no `env/*.json` sets it) means `SentryFlutter.init` in `main.dart` still runs
  /// (it must, to wrap `runApp`) but its own SDK treats an empty DSN as "disabled" —
  /// no events are ever sent, no network call is made. No real Sentry account
  /// exists yet, so `env/dev.json`/`env/prod.json` deliberately leave this unset.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
}
