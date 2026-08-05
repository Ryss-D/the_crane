from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.platform_config import PlatformConfig, PlatformConfigAudit
from app.models.user import User
from app.services.config import CACHE_PREFIX, get_config, set_config
from tests.conftest import FakeRedis


async def test_get_config_missing_returns_none(
    session_maker: async_sessionmaker[AsyncSession], fake_redis: FakeRedis
) -> None:
    async with session_maker() as session:
        assert await get_config(session, fake_redis, "nope") is None


async def test_set_then_get_roundtrip(
    session_maker: async_sessionmaker[AsyncSession], fake_redis: FakeRedis
) -> None:
    value = {"moto": {"base": 40000, "per_km": 3500, "min": 50000}}
    async with session_maker() as session:
        await set_config(session, fake_redis, "pricing", value)
    async with session_maker() as session:
        assert await get_config(session, fake_redis, "pricing") == value


async def test_get_config_serves_from_cache(
    session_maker: async_sessionmaker[AsyncSession], fake_redis: FakeRedis
) -> None:
    async with session_maker() as session:
        await set_config(session, fake_redis, "dispatch", {"offer_ttl_seconds": 30})
    async with session_maker() as session:
        assert await get_config(session, fake_redis, "dispatch") == {"offer_ttl_seconds": 30}
        assert CACHE_PREFIX + "dispatch" in fake_redis.store
        # Delete the DB row: a second read must still succeed, proving the cache is hit.
        await session.execute(delete(PlatformConfig).where(PlatformConfig.key == "dispatch"))
        await session.commit()
        assert await get_config(session, fake_redis, "dispatch") == {"offer_ttl_seconds": 30}


async def test_set_config_busts_cache(
    session_maker: async_sessionmaker[AsyncSession], fake_redis: FakeRedis
) -> None:
    async with session_maker() as session:
        await set_config(session, fake_redis, "settlement", {"period": "weekly"})
        await get_config(session, fake_redis, "settlement")
        assert CACHE_PREFIX + "settlement" in fake_redis.store

        await set_config(session, fake_redis, "settlement", {"period": "daily"})
        assert CACHE_PREFIX + "settlement" not in fake_redis.store
        assert await get_config(session, fake_redis, "settlement") == {"period": "daily"}


async def test_set_config_writes_audit_rows(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    admin_user: User,
) -> None:
    async with session_maker() as session:
        await set_config(session, fake_redis, "commission", {"mode": "percent"}, user=admin_user)
        await set_config(session, fake_redis, "commission", {"mode": "flat"}, user=admin_user)

        audits = (
            await session.scalars(
                select(PlatformConfigAudit).where(PlatformConfigAudit.key == "commission")
            )
        ).all()
        assert len(audits) == 2
        creation = next(a for a in audits if a.old_value is None)
        update = next(a for a in audits if a.old_value is not None)
        assert creation.new_value == {"mode": "percent"}
        assert update.old_value == {"mode": "percent"}
        assert update.new_value == {"mode": "flat"}
        assert all(a.changed_by == admin_user.id for a in audits)

        row = await session.scalar(select(PlatformConfig).where(PlatformConfig.key == "commission"))
        assert row is not None
        assert row.updated_by == admin_user.id
