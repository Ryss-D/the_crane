from collections.abc import AsyncIterator
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.database import get_session
from app.core.security import get_token_verifier
from app.main import create_app
from app.models.base import Base
from app.models.user import User, UserRole


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

    async def get(self, key: str) -> str | None:
        return self.store.get(key)

    async def set(self, key: str, value: str, ex: int | None = None) -> None:
        self.store[key] = value

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
