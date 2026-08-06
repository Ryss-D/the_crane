"""Application settings, read from environment variables (and .env in dev)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+asyncpg://crane:crane@localhost:5432/crane"
    redis_url: str = "redis://localhost:6379/0"
    firebase_credentials_path: str | None = None
    # Unset -> pricing falls back to haversine road-distance estimates (JOB-4).
    google_maps_api_key: str | None = None
    env: str = "dev"
    # DSP-4 guard: background workers (offer-expiry sweep) start in the app
    # lifespan only when true. Tests set ENABLE_WORKERS=false.
    enable_workers: bool = True
    # WEB-1: comma-separated origins allowed to call the API from a browser
    # (web-client/admin). Defaults cover both apps' local Vite dev servers;
    # set CORS_ORIGINS in each environment's .env once real domains exist.
    cors_origins: str = "http://localhost:5173,http://localhost:5174"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
