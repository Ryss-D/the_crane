"""Application settings, read from environment variables (and .env in dev)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+asyncpg://crane:crane@localhost:5432/crane"
    redis_url: str = "redis://localhost:6379/0"
    firebase_credentials_path: str | None = None
    env: str = "dev"


@lru_cache
def get_settings() -> Settings:
    return Settings()
