import asyncio
import math
from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core import security
from app.core.config import get_settings
from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import get_token_verifier
from app.main import create_app
from app.models.base import Base
from app.models.driver import DriverProfile, DriverStatus, Truck, TruckCapacity, TruckType
from app.models.job import Job, JobStatus, VehicleType
from app.models.user import User, UserRole
from app.services.config import set_config
from app.services.connection_manager import ConnectionManager, get_connection_manager
from app.services.dispatch import add_driver_to_geo


@pytest.fixture
async def session_maker() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = create_async_engine(
        "sqlite+aiosqlite://",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False)
    await engine.dispose()


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in km — good enough for test-scale geo assertions."""
    r = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


_GEO_UNIT_SCALE = {"km": 1.0, "m": 1000.0, "mi": 0.621371, "ft": 3280.84}


class _FakePubSub:
    """Minimal redis.asyncio PubSub emulation (TRK-1): subscribe() registers this
    session's queue against the shared FakeRedis, get_message() drains it — same
    polling-loop shape connection_manager.py drives against the real client, so app
    code is unchanged in prod."""

    def __init__(self, redis: "FakeRedis") -> None:
        self._redis = redis
        self._channels: set[str] = set()
        self._queue: asyncio.Queue[str] = asyncio.Queue()

    async def subscribe(self, *channels: str) -> None:
        for channel in channels:
            self._channels.add(channel)
            self._redis.subscribers.setdefault(channel, []).append(self._queue)

    async def unsubscribe(self, *channels: str) -> None:
        for channel in channels:
            self._channels.discard(channel)
            subs = self._redis.subscribers.get(channel)
            if subs and self._queue in subs:
                subs.remove(self._queue)

    async def get_message(
        self, *, ignore_subscribe_messages: bool = True, timeout: float | None = None
    ) -> dict[str, str] | None:
        try:
            data = (
                await asyncio.wait_for(self._queue.get(), timeout=timeout)
                if timeout
                else self._queue.get_nowait()
            )
        except (TimeoutError, asyncio.QueueEmpty):
            return None
        return {"type": "message", "data": data}

    async def close(self) -> None:
        for channel in list(self._channels):
            await self.unsubscribe(channel)


class FakeRedis:
    """In-memory stand-in for redis.asyncio.Redis (decode_responses=True subset).

    DSP-1 adds a small GEOADD/GEOSEARCH/ZREM emulation (haversine over stored plain
    lat/lng coords) so the dispatch service can be exercised without a real Redis —
    method signatures mirror redis.asyncio.Redis's so app code is unchanged in prod.
    TRK-1 adds a small pub/sub emulation (publish/pubsub) for the same reason.
    """

    def __init__(self) -> None:
        self.store: dict[str, str] = {}
        self.ttls: dict[str, int | None] = {}
        # geo key -> {member: (lng, lat)}
        self.geo: dict[str, dict[str, tuple[float, float]]] = {}
        # pub/sub channel -> list of subscribed sessions' queues
        self.subscribers: dict[str, list[asyncio.Queue[str]]] = {}

    async def publish(self, channel: str, message: str) -> int:
        queues = self.subscribers.get(channel, [])
        for queue in queues:
            queue.put_nowait(message)
        return len(queues)

    def pubsub(self) -> _FakePubSub:
        return _FakePubSub(self)

    async def get(self, key: str) -> str | None:
        return self.store.get(key)

    async def set(self, key: str, value: str, ex: int | None = None) -> None:
        self.store[key] = value
        self.ttls[key] = ex

    async def delete(self, *keys: str) -> None:
        for key in keys:
            self.store.pop(key, None)

    async def geoadd(self, name: str, values: list) -> int:
        bucket = self.geo.setdefault(name, {})
        added = 0
        it = iter(values)
        for lng, lat, member in zip(it, it, it, strict=True):
            if member not in bucket:
                added += 1
            bucket[member] = (float(lng), float(lat))
        return added

    async def zrem(self, name: str, *values: str) -> int:
        bucket = self.geo.get(name)
        if not bucket:
            return 0
        removed = 0
        for member in values:
            if bucket.pop(member, None) is not None:
                removed += 1
        return removed

    async def geopos(self, name: str, *values: str) -> list:
        bucket = self.geo.get(name, {})
        return [bucket.get(member, None) for member in values]

    async def geosearch(
        self,
        name: str,
        *,
        longitude: float | None = None,
        latitude: float | None = None,
        radius: float | None = None,
        unit: str = "km",
        sort: str | None = None,
        withdist: bool = False,
        count: int | None = None,
        **_ignored: object,
    ) -> list:
        bucket = self.geo.get(name, {})
        scale = _GEO_UNIT_SCALE[unit]
        assert longitude is not None and latitude is not None
        results = []
        for member, (lng, lat) in bucket.items():
            dist = _haversine_km(latitude, longitude, lat, lng) * scale
            if radius is None or dist <= radius:
                results.append((member, dist))
        if sort != "DESC":
            results.sort(key=lambda pair: pair[1])
        else:
            results.sort(key=lambda pair: -pair[1])
        if count is not None:
            results = results[:count]
        if withdist:
            return [(member, round(dist, 4)) for member, dist in results]
        return [member for member, _ in results]


@pytest.fixture
def fake_redis() -> FakeRedis:
    return FakeRedis()


@pytest.fixture
def verified_tokens() -> dict[str, dict[str, Any]]:
    """Map of accepted bearer tokens -> fake Firebase claims. Tests add entries."""
    return {}


@pytest.fixture
def fcm_sent(monkeypatch: pytest.MonkeyPatch) -> list[Any]:
    """TRK-3 push-sending seam: makes Firebase Admin look "configured" (like
    app/core/security.py, the actual cert file is never touched -- the module's
    already-initialized-app check is monkeypatched instead) and replaces
    firebase_admin.messaging.send with a fake that records every message it would
    have sent, rather than calling the real Firebase API. Yields that list."""
    import firebase_admin.messaging as messaging

    monkeypatch.setenv("FIREBASE_CREDENTIALS_PATH", "/fake/firebase-creds.json")
    get_settings.cache_clear()
    monkeypatch.setattr(security, "_firebase_app", object())

    sent: list[Any] = []

    def fake_send(message: Any, dry_run: bool = False, app: Any = None) -> str:
        sent.append(message)
        return "mock-message-id"

    monkeypatch.setattr(messaging, "send", fake_send)
    yield sent
    get_settings.cache_clear()


@pytest.fixture
def connection_manager() -> ConnectionManager:
    """Fresh WS connection manager per test — mirrors fake_redis's isolation (the
    default get_connection_manager() is a process-wide singleton in prod, which would
    otherwise leak subscriptions/relay tasks across tests)."""
    return ConnectionManager()


@pytest.fixture
def app(
    session_maker: async_sessionmaker[AsyncSession],
    verified_tokens: dict[str, dict[str, Any]],
    fake_redis: FakeRedis,
    connection_manager: ConnectionManager,
) -> FastAPI:
    app = create_app()

    async def override_session() -> AsyncIterator[AsyncSession]:
        async with session_maker() as session:
            yield session

    def fake_verifier(token: str) -> dict[str, Any]:
        if token not in verified_tokens:
            raise ValueError("invalid token")
        return verified_tokens[token]

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_token_verifier] = lambda: fake_verifier
    app.dependency_overrides[get_redis] = lambda: fake_redis
    app.dependency_overrides[get_connection_manager] = lambda: connection_manager
    return app


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[AsyncClient]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client


async def _create_user(
    session_maker: async_sessionmaker[AsyncSession], firebase_uid: str, role: UserRole
) -> User:
    async with session_maker() as session:
        user = User(
            firebase_uid=firebase_uid,
            role=role,
            name="Test User",
            phone="+573001112233",
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user


@pytest.fixture
async def customer_user(session_maker: async_sessionmaker[AsyncSession]) -> User:
    return await _create_user(session_maker, "customer-uid", UserRole.customer)


@pytest.fixture
async def admin_user(session_maker: async_sessionmaker[AsyncSession]) -> User:
    return await _create_user(session_maker, "admin-uid", UserRole.admin)


@pytest.fixture
async def driver_user(session_maker: async_sessionmaker[AsyncSession]) -> User:
    return await _create_user(session_maker, "driver-uid", UserRole.driver)


# Mirrors scripts/seed.py DEFAULT_CONFIG; kept local so tests stay import-clean.
TEST_CONFIG: dict[str, Any] = {
    "pricing": {
        "moto": {"base": 40000, "per_km": 3500, "min": 50000},
        "car": {"base": 60000, "per_km": 5000, "min": 80000},
        "suv": {"base": 70000, "per_km": 5500, "min": 90000},
    },
    "commission": {"mode": "percent", "rate": {"moto": 0.15, "car": 0.15, "suv": 0.15}},
    "settlement": {"balance_cap": None, "period": "weekly"},
    "dispatch": {
        "offer_ttl_seconds": 30,
        "search_radius_km": 10,
        "radius_widen_factor": 2,
        "cancel_grace_seconds": 60,
        "rejection_cooldown_minutes": 10,
    },
}


@pytest.fixture
async def seeded_config(
    session_maker: async_sessionmaker[AsyncSession], fake_redis: FakeRedis
) -> dict[str, Any]:
    """Write the default platform config (pricing/commission/settlement/dispatch)."""
    async with session_maker() as session:
        for key, value in TEST_CONFIG.items():
            await set_config(session, fake_redis, key, value)
    return TEST_CONFIG


async def make_job(
    session_maker: async_sessionmaker[AsyncSession],
    customer: User,
    *,
    status: JobStatus = JobStatus.requested,
    driver: User | None = None,
    **overrides: Any,
) -> Job:
    """Insert a job directly (state-machine and endpoint tests set up mid-flow states)."""
    fields: dict[str, Any] = {
        "customer_id": customer.id,
        "driver_id": driver.id if driver else None,
        "vehicle_type": VehicleType.car,
        "status": status,
        "pickup_lat": 6.2442,
        "pickup_lng": -75.5812,
        "dropoff_lat": 6.2000,
        "dropoff_lng": -75.5700,
        "pickup_address": "Calle 10 # 43-12, Medellín",
        "dropoff_address": "Carrera 70 # 1-141, Medellín",
        "quoted_price": 110000,
    }
    fields.update(overrides)
    async with session_maker() as session:
        job = Job(**fields)
        session.add(job)
        await session.commit()
        await session.refresh(job)
        return job


async def make_available_driver(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    *,
    firebase_uid: str,
    lat: float = 6.2442,
    lng: float = -75.5812,
    capacity: TruckCapacity = TruckCapacity.car,
    verified: bool = True,
    status: DriverStatus = DriverStatus.available,
    plate: str | None = None,
) -> User:
    """Create a driver with a truck, driver_profile, and (if available) a live geo
    entry — the DSP-1/DSP-2 building block dispatch tests need. Also used by a couple
    of pre-existing JOB-5 API tests: wiring DSP-2 into POST /v1/jobs and the
    driver-cancel edge means a job creation/cancel with zero reachable drivers now
    legitimately ends in `no_drivers`, so those tests seed one reachable driver to
    keep exercising the `matching` path they were written for.
    """
    user = await _create_user(session_maker, firebase_uid, UserRole.driver)
    async with session_maker() as session:
        session.add(DriverProfile(user_id=user.id, status=status, verified=verified))
        session.add(
            Truck(
                plate=plate or firebase_uid[:16],
                type=TruckType.car,
                capacity=capacity,
                driver_id=user.id,
            )
        )
        await session.commit()
    if status is DriverStatus.available:
        await add_driver_to_geo(fake_redis, user.id, capacity, lat, lng)
    return user
