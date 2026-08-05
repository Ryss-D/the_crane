from typing import Any

from httpx import AsyncClient

from app.models.user import User


async def test_me_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/me")
    assert response.status_code == 401


async def test_me_with_invalid_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/me", headers={"Authorization": "Bearer garbage"})
    assert response.status_code == 401


async def test_me_with_unknown_user_returns_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]]
) -> None:
    verified_tokens["valid-token"] = {"uid": "never-synced-uid"}
    response = await client.get("/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 404


async def test_me_with_known_user_returns_200(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["valid-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get("/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(customer_user.id)
    assert body["firebase_uid"] == customer_user.firebase_uid
    assert body["role"] == "customer"


async def test_admin_route_rejects_non_admin_with_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get(
        "/v1/admin/ping", headers={"Authorization": "Bearer customer-token"}
    )
    assert response.status_code == 403


async def test_admin_route_allows_admin(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    admin_user: User,
) -> None:
    verified_tokens["admin-token"] = {"uid": admin_user.firebase_uid}
    response = await client.get("/v1/admin/ping", headers={"Authorization": "Bearer admin-token"})
    assert response.status_code == 200
    assert response.json()["admin"] == admin_user.firebase_uid
