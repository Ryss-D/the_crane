"""Application settings, read from environment variables (and .env in dev)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+asyncpg://crane:crane@localhost:5432/crane"
    redis_url: str = "redis://localhost:6379/0"
    firebase_credentials_path: str | None = None
    # Unset -> pricing falls back to haversine road-distance estimates (JOB-4);
    # also backs the /v1/places/* and /v1/directions/route proxy endpoints
    # (app/services/places.py, app/api/places.py) so client apps never hold a
    # Places-or-Directions-capable key themselves (Android/iOS app-restricted
    # keys don't work for raw REST calls anyway). A *server-side* key, distinct
    # from the Android/iOS/Web client keys — ideally IP-restricted once real
    # hosting exists (OPS-3, not yet), scoped to Places API + Directions API only.
    google_maps_api_key: str | None = None
    env: str = "dev"
    # DSP-4 guard: background workers (offer-expiry sweep) start in the app
    # lifespan only when true. Tests set ENABLE_WORKERS=false.
    enable_workers: bool = True
    # WEB-1: comma-separated origins allowed to call the API from a browser
    # (web-client/admin). Defaults cover both apps' local Vite dev servers;
    # set CORS_ORIGINS in each environment's .env once real domains exist.
    cors_origins: str = "http://localhost:5173,http://localhost:5174"
    # PAY-1..5: Wompi (Bancolombia) payments. A 5th external secret set,
    # distinct from the 4 Google Maps keys (Android/iOS/Web client + the
    # server-side Places/Directions one) — unset means every WompiGateway
    # call raises WompiNotConfiguredError (mapped to a 503) rather than
    # silently pretending to succeed, same fallback discipline as
    # google_maps_api_key above.
    wompi_public_key: str | None = None
    wompi_private_key: str | None = None
    wompi_events_key: str | None = None
    wompi_env: str = "sandbox"  # or "prod"
    # OPS-6: Sentry DSN for error tracking. Unset -> app/main.py's create_app skips
    # the sentry_sdk.init() call entirely (no-op, same fallback discipline as
    # google_maps_api_key/wompi_* above) -- no Sentry account exists yet as of this
    # pass. Once set, errors report with request context (via sentry-sdk's FastAPI
    # integration) and job_id (tagged in app/api/jobs.py's _get_job_or_404).
    sentry_dsn: str | None = None

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
