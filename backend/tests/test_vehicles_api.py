"""CUS-6 tests: customer saved-vehicles CRUD, scoped to the authenticated user."""

from datetime import UTC, datetime, timedelta
from typing import Any

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import CustomerVehicle, VehicleType
from app.models.user import User, UserRole
from tests.conftest import _create_user

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}


async def test_list_vehicles_empty(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get("/v1/me/vehicles", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    assert response.json() == []


async def test_create_vehicle(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post(
        "/v1/me/vehicles",
        headers=AUTH_CUSTOMER,
        json={"type": "moto", "plate": "ABC123"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["type"] == "moto"
    assert body["plate"] == "ABC123"
    assert body["make"] is None
    assert body["model"] is None

    second = await client.post(
        "/v1/me/vehicles",
        headers=AUTH_CUSTOMER,
        json={"type": "car", "make": "Mazda", "model": "3", "plate": "XYZ987"},
    )
    assert second.status_code == 201

    listed = await client.get("/v1/me/vehicles", headers=AUTH_CUSTOMER)
    assert listed.status_code == 200
    plates = {v["plate"] for v in listed.json()}
    assert plates == {"ABC123", "XYZ987"}


async def test_list_vehicles_newest_first(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    """Inserted directly with explicit timestamps -- sqlite's CURRENT_TIMESTAMP has
    1s resolution, so two live POSTs in the same test can tie (same caveat noted in
    tests/test_admin_api.py); this proves the ORDER BY itself, independent of that."""
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    older = datetime(2026, 1, 1, tzinfo=UTC)
    newer = older + timedelta(days=1)
    async with session_maker() as session:
        session.add(
            CustomerVehicle(
                user_id=customer_user.id, type=VehicleType.moto, plate="OLD001", created_at=older
            )
        )
        session.add(
            CustomerVehicle(
                user_id=customer_user.id, type=VehicleType.car, plate="NEW001", created_at=newer
            )
        )
        await session.commit()

    response = await client.get("/v1/me/vehicles", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    body = response.json()
    assert [v["plate"] for v in body] == ["NEW001", "OLD001"]


async def test_list_vehicles_scoped_to_caller(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    other = await _create_user(session_maker, "other-customer-uid", UserRole.customer)
    async with session_maker() as session:
        session.add(CustomerVehicle(user_id=other.id, type=VehicleType.moto, plate="OTHER01"))
        await session.commit()

    response = await client.get("/v1/me/vehicles", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    assert response.json() == []


async def test_patch_vehicle_updates_subset_of_fields(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    create = await client.post(
        "/v1/me/vehicles",
        headers=AUTH_CUSTOMER,
        json={"type": "moto", "plate": "ABC123"},
    )
    vehicle_id = create.json()["id"]

    response = await client.patch(
        f"/v1/me/vehicles/{vehicle_id}",
        headers=AUTH_CUSTOMER,
        json={"make": "Yamaha"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["make"] == "Yamaha"
    assert body["plate"] == "ABC123"  # untouched
    assert body["type"] == "moto"  # untouched


async def test_patch_vehicle_not_owned_is_404(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    other = await _create_user(session_maker, "other-customer-uid-2", UserRole.customer)
    async with session_maker() as session:
        vehicle = CustomerVehicle(user_id=other.id, type=VehicleType.car, plate="OTHER02")
        session.add(vehicle)
        await session.commit()
        await session.refresh(vehicle)
        vehicle_id = vehicle.id

    response = await client.patch(
        f"/v1/me/vehicles/{vehicle_id}", headers=AUTH_CUSTOMER, json={"make": "Nope"}
    )
    assert response.status_code == 404


async def test_delete_vehicle(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    create = await client.post(
        "/v1/me/vehicles",
        headers=AUTH_CUSTOMER,
        json={"type": "suv", "plate": "DEL0001"},
    )
    vehicle_id = create.json()["id"]

    response = await client.delete(f"/v1/me/vehicles/{vehicle_id}", headers=AUTH_CUSTOMER)
    assert response.status_code == 204

    listed = await client.get("/v1/me/vehicles", headers=AUTH_CUSTOMER)
    assert listed.json() == []


async def test_delete_vehicle_not_owned_is_404(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    other = await _create_user(session_maker, "other-customer-uid-3", UserRole.customer)
    async with session_maker() as session:
        vehicle = CustomerVehicle(user_id=other.id, type=VehicleType.car, plate="OTHER03")
        session.add(vehicle)
        await session.commit()
        await session.refresh(vehicle)
        vehicle_id = vehicle.id

    response = await client.delete(f"/v1/me/vehicles/{vehicle_id}", headers=AUTH_CUSTOMER)
    assert response.status_code == 404


async def test_delete_unknown_vehicle_is_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.delete(
        "/v1/me/vehicles/00000000-0000-0000-0000-000000000000", headers=AUTH_CUSTOMER
    )
    assert response.status_code == 404
