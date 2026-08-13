"""app/core/database.py and app/core/redis.py: the real engine/sessionmaker/client
factories and their shutdown hooks (`dispose_engine`/`close_redis`).

Every other test in this suite talks to the DB/Redis through the overridden
`get_session`/`get_redis` dependencies (aiosqlite session_maker / FakeRedis from
tests/conftest.py) precisely so pytest never needs a live Postgres or Redis server --
so these factories themselves are otherwise never exercised.

They ARE safely testable without live infra, though: `create_async_engine` and
`redis.from_url` are both lazy -- constructing them (and even entering/disposing an
AsyncSession/closing the client) never opens a socket, only *using* the connection
would (verified: this whole file runs offline). What's genuinely untestable without a
live Postgres/Redis is the actual query/command execution against `postgresql://
localhost:5432` -- not attempted here.
"""

from collections.abc import AsyncIterator

import pytest
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core import database
from app.core import redis as redis_module
from app.core.config import get_settings


@pytest.fixture(autouse=True)
async def _reset_infra_caches() -> AsyncIterator[None]:
    """`get_engine`/`get_sessionmaker`/`get_redis_client` are process-wide
    `lru_cache` singletons. Clearing before AND after each test keeps this file's
    tests isolated from each other, and disposing whatever got created keeps a
    real-but-never-connected engine/client from lingering into the rest of the
    session (harmless either way, since every other test goes through the
    dependency-override fakes instead -- this is just hygiene)."""

    async def _reset() -> None:
        if database.get_engine.cache_info().currsize:
            await database.dispose_engine()
        database.get_engine.cache_clear()
        database.get_sessionmaker.cache_clear()
        if redis_module.get_redis_client.cache_info().currsize:
            await redis_module.close_redis()
        redis_module.get_redis_client.cache_clear()

    await _reset()
    yield
    await _reset()


# ---- database.py --------------------------------------------------------------------


async def test_get_engine_builds_engine_for_configured_database_url() -> None:
    engine = database.get_engine()
    assert isinstance(engine, AsyncEngine)
    assert engine.url.drivername == "postgresql+asyncpg"
    assert engine.url.database == "crane"
    # lru_cache: same call returns the same instance rather than building a second one.
    assert database.get_engine() is engine


async def test_get_sessionmaker_returns_async_sessionmaker_bound_to_get_engine() -> None:
    sessionmaker = database.get_sessionmaker()
    assert isinstance(sessionmaker, async_sessionmaker)
    async with sessionmaker() as session:
        assert isinstance(session, AsyncSession)
        assert session.bind is database.get_engine()
        assert session.sync_session.expire_on_commit is False


async def test_get_session_yields_exactly_one_session_then_stops() -> None:
    gen = database.get_session()
    session = await gen.__anext__()
    assert isinstance(session, AsyncSession)
    with pytest.raises(StopAsyncIteration):
        await gen.__anext__()


async def test_dispose_engine_is_noop_when_engine_never_created() -> None:
    assert database.get_engine.cache_info().currsize == 0
    await database.dispose_engine()  # must not raise / must not build an engine
    assert database.get_engine.cache_info().currsize == 0


async def test_dispose_engine_disposes_an_already_created_engine(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database.get_engine()  # populate the cache so dispose_engine has something to do
    disposed: list[bool] = []
    original_dispose = AsyncEngine.dispose

    async def tracking_dispose(self: AsyncEngine) -> None:
        disposed.append(True)
        await original_dispose(self)

    # AsyncEngine.dispose is read-only on the instance -- patch the class instead.
    monkeypatch.setattr(AsyncEngine, "dispose", tracking_dispose)

    await database.dispose_engine()

    assert disposed == [True]


# ---- redis.py -----------------------------------------------------------------------


async def test_get_redis_client_builds_client_for_configured_redis_url() -> None:
    client = redis_module.get_redis_client()
    assert isinstance(client, redis.Redis)
    kwargs = client.connection_pool.connection_kwargs
    settings_url = get_settings().redis_url
    assert f"{kwargs['host']}:{kwargs['port']}" in settings_url
    # lru_cache: same call returns the same instance rather than building a second one.
    assert redis_module.get_redis_client() is client


def test_get_redis_dependency_returns_the_cached_client() -> None:
    assert redis_module.get_redis() is redis_module.get_redis_client()


async def test_close_redis_is_noop_when_client_never_created() -> None:
    assert redis_module.get_redis_client.cache_info().currsize == 0
    await redis_module.close_redis()  # must not raise / must not build a client
    assert redis_module.get_redis_client.cache_info().currsize == 0


async def test_close_redis_closes_an_already_created_client(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = redis_module.get_redis_client()
    closed: list[bool] = []
    original_aclose = client.aclose

    async def tracking_aclose() -> None:
        closed.append(True)
        await original_aclose()

    monkeypatch.setattr(client, "aclose", tracking_aclose)

    await redis_module.close_redis()

    assert closed == [True]
