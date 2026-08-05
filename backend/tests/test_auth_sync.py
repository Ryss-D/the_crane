from typing import Any

from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.user import User

AUTH = {"Authorization": "Bearer sync-token"}


async def _user_count(session_maker: async_sessionmaker[AsyncSession]) -> int:
    async with session_maker() as session:
        return (await session.scalar(select(func.count()).select_from(User))) or 0


async def test_sync_requires_token(client: AsyncClient) -> None:
    response = await client.post("/v1/auth/sync")
    assert response.status_code == 401


async def test_sync_creates_customer_from_body(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["sync-token"] = {"uid": "new-uid"}
    response = await client.post(
        "/v1/auth/sync", headers=AUTH, json={"name": "Ana", "phone": "+573001234567"}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["firebase_uid"] == "new-uid"
    assert body["role"] == "customer"
    assert body["name"] == "Ana"
    assert body["phone"] == "+573001234567"
    assert await _user_count(session_maker) == 1


async def test_sync_falls_back_to_token_claims(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]]
) -> None:
    verified_tokens["sync-token"] = {
        "uid": "claims-uid",
        "name": "Claims Name",
        "phone_number": "+573009998877",
        "email": "claims@example.com",
    }
    response = await client.post("/v1/auth/sync", headers=AUTH)
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Claims Name"
    assert body["phone"] == "+573009998877"
    assert body["email"] == "claims@example.com"


async def test_sync_allows_missing_profile_fields(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]]
) -> None:
    verified_tokens["sync-token"] = {"uid": "bare-uid"}
    response = await client.post("/v1/auth/sync", headers=AUTH)
    assert response.status_code == 200
    body = response.json()
    assert body["name"] is None
    assert body["phone"] is None


async def test_sync_is_idempotent(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["sync-token"] = {"uid": "repeat-uid"}
    first = await client.post("/v1/auth/sync", headers=AUTH, json={"name": "First"})
    second = await client.post("/v1/auth/sync", headers=AUTH, json={"name": "Second"})
    assert first.status_code == second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    # Second call returns the existing row untouched.
    assert second.json()["name"] == "First"
    assert await _user_count(session_maker) == 1


async def test_patch_me_updates_profile_fields(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.patch(
        "/v1/me",
        headers={"Authorization": "Bearer customer-token"},
        json={"name": "New Name", "email": "new@example.com", "fcm_token": "fcm-abc"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "New Name"
    assert body["email"] == "new@example.com"
    assert body["fcm_token"] == "fcm-abc"
    # Untouched fields survive.
    assert body["phone"] == customer_user.phone


async def test_patch_me_partial_update_leaves_other_fields(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.patch(
        "/v1/me",
        headers={"Authorization": "Bearer customer-token"},
        json={"fcm_token": "only-this"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["fcm_token"] == "only-this"
    assert body["name"] == customer_user.name


async def test_patch_me_requires_auth(client: AsyncClient) -> None:
    response = await client.patch("/v1/me", json={"name": "Nope"})
    assert response.status_code == 401
