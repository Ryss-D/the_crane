from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import get_token_verifier
from app.main import create_app
from app.models.base import Base
from app.models.job import Job, JobStatus, VehicleType
from app.models.user import User, UserRole
from app.services.config import set_config


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


class FakeRedis:
    """In-memory stand-in for redis.asyncio.Redis (decode_responses=True subset)."""

    def __init__(self) -> None:
        self.store: dict[str, str] = {}
        self.ttls: dict[str, int | None] = {}

    async def get(self, key: str) -> str | None:
        return self.store.get(key)

    async def set(self, key: str, value: str, ex: int | None = None) -> None:
        self.store[key] = value
        self.ttls[key] = ex

    async def delete(self, *keys: str) -> None:
        for key in keys:
            self.store.pop(key, None)


@pytest.fixture
def fake_redis() -> FakeRedis:
    return FakeRedis()


@pytest.fixture
def verified_tokens() -> dict[str, dict[str, Any]]:
    """Map of accepted bearer tokens -> fake Firebase claims. Tests add entries."""
    return {}


@pytest.fixture
def app(
    session_maker: async_sessionmaker[AsyncSession],
    verified_tokens: dict[str, dict[str, Any]],
    fake_redis: FakeRedis,
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
