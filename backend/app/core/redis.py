"""Redis client (redis.asyncio) as an injectable dependency.

`get_redis` is the FastAPI dependency; tests override it (or pass a tiny in-memory fake
directly to services) so pytest never needs a Redis server.
"""

from functools import lru_cache

import redis.asyncio as redis

from app.core.config import get_settings


@lru_cache
def get_redis_client() -> redis.Redis:
    return redis.from_url(get_settings().redis_url, decode_responses=True)


def get_redis() -> redis.Redis:
    """FastAPI dependency returning the shared Redis client; override in tests."""
    return get_redis_client()


async def close_redis() -> None:
    """Close the client on shutdown (no-op if it was never created)."""
    if get_redis_client.cache_info().currsize:
        await get_redis_client().aclose()
