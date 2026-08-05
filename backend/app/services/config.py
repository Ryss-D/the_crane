"""Platform config service (JOB-2): Redis-cached reads, audited writes with cache bust.

Both functions take the session and redis client as arguments (injected by callers via
the `get_session` / `get_redis` dependencies), so tests can pass an in-memory fake redis.
"""

import json
from typing import Any, Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.platform_config import PlatformConfig, PlatformConfigAudit
from app.models.user import User

CACHE_PREFIX = "platform_config:"
CACHE_TTL_SECONDS = 300


class RedisLike(Protocol):
    """The slice of redis.asyncio.Redis this service uses (decode_responses=True)."""

    async def get(self, key: str) -> str | None: ...
    async def set(self, key: str, value: str, ex: int | None = None) -> Any: ...
    async def delete(self, *keys: str) -> Any: ...


async def get_config(session: AsyncSession, redis: RedisLike, key: str) -> Any | None:
    """Return the JSON value for `key` (Redis cache first, DB on miss), or None if absent."""
    cached = await redis.get(CACHE_PREFIX + key)
    if cached is not None:
        return json.loads(cached)

    row = await session.scalar(select(PlatformConfig).where(PlatformConfig.key == key))
    if row is None:
        return None
    await redis.set(CACHE_PREFIX + key, json.dumps(row.value), ex=CACHE_TTL_SECONDS)
    return row.value


async def set_config(
    session: AsyncSession,
    redis: RedisLike,
    key: str,
    value: Any,
    user: User | None = None,
) -> PlatformConfig:
    """Upsert `key`, write an audit row (old + new value), commit, and bust the cache."""
    row = await session.scalar(select(PlatformConfig).where(PlatformConfig.key == key))
    old_value = row.value if row is not None else None
    if row is None:
        row = PlatformConfig(key=key, value=value, updated_by=user.id if user else None)
        session.add(row)
    else:
        row.value = value
        row.updated_by = user.id if user else None
    session.add(
        PlatformConfigAudit(
            key=key,
            old_value=old_value,
            new_value=value,
            changed_by=user.id if user else None,
        )
    )
    await session.commit()
    await session.refresh(row)
    await redis.delete(CACHE_PREFIX + key)
    return row
