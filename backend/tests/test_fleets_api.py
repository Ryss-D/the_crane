"""FLT-1 tests: fleet CRUD (create own fleet, view it, attach/detach trucks)."""

from typing import Any

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import Truck, TruckCapacity, TruckType
from app.models.user import User, UserRole
from tests.conftest import _create_user

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}


async def _register_driver_truck(
    session_maker: async_sessionmaker[AsyncSession],
    *,
    firebase_uid: str,
    plate: str,
) -> Truck:
    async with session_maker() as session:
        driver = User(
            firebase_uid=firebase_uid, role=UserRole.driver, name="D", phone="+573000000000"
        )
        session.add(driver)
        await session.flush()
        truck = Truck(
            plate=plate, type=TruckType.car, capacity=TruckCapacity.car, driver_id=driver.id
        )
        session.add(truck)
        await session.commit()
        await session.refresh(truck)
        return truck


async def test_create_fleet_flips_role_and_returns_it(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post(
        "/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Grúas del Poblado"}
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Grúas del Poblado"
    assert body["owner_user_id"] == str(customer_user.id)
    assert body["trucks"] == []

    async with session_maker() as session:
        user = await session.get(User, customer_user.id)
        assert user is not None
        assert user.role is UserRole.fleet_owner


async def test_create_fleet_twice_is_409(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    first = await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet A"})
    assert first.status_code == 201
    second = await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet B"})
    assert second.status_code == 409


async def test_get_my_fleet_404_before_creation(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get("/v1/fleets/me", headers=AUTH_CUSTOMER)
    assert response.status_code == 404


async def test_add_and_remove_truck_from_fleet(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    create = await client.post(
        "/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Grúas del Poblado"}
    )
    assert create.status_code == 201

    truck = await _register_driver_truck(
        session_maker, firebase_uid="fleet-driver-1", plate="FLTTRK1"
    )

    add = await client.post(f"/v1/fleets/me/trucks/{truck.id}", headers=AUTH_CUSTOMER)
    assert add.status_code == 200
    body = add.json()
    assert len(body["trucks"]) == 1
    assert body["trucks"][0]["id"] == str(truck.id)

    async with session_maker() as session:
        refreshed = await session.get(Truck, truck.id)
        assert refreshed is not None
        assert refreshed.fleet_id is not None

    remove = await client.delete(f"/v1/fleets/me/trucks/{truck.id}", headers=AUTH_CUSTOMER)
    assert remove.status_code == 200
    assert remove.json()["trucks"] == []

    async with session_maker() as session:
        refreshed = await session.get(Truck, truck.id)
        assert refreshed is not None
        assert refreshed.fleet_id is None


async def test_add_truck_already_in_a_fleet_is_409(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet A"})

    other_owner = await _create_user(session_maker, "other-owner-uid", UserRole.customer)
    verified_tokens["other-owner-token"] = {"uid": other_owner.firebase_uid}
    other_headers = {"Authorization": "Bearer other-owner-token"}
    await client.post("/v1/fleets/me", headers=other_headers, json={"name": "Fleet B"})

    truck = await _register_driver_truck(
        session_maker, firebase_uid="fleet-driver-2", plate="FLTTRK2"
    )
    first = await client.post(f"/v1/fleets/me/trucks/{truck.id}", headers=other_headers)
    assert first.status_code == 200

    second = await client.post(f"/v1/fleets/me/trucks/{truck.id}", headers=AUTH_CUSTOMER)
    assert second.status_code == 409


async def test_remove_truck_not_in_caller_fleet_is_404(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet A"})

    truck = await _register_driver_truck(
        session_maker, firebase_uid="unclaimed-driver", plate="FLTTRK3"
    )
    response = await client.delete(f"/v1/fleets/me/trucks/{truck.id}", headers=AUTH_CUSTOMER)
    assert response.status_code == 404


async def test_add_truck_without_fleet_is_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post(
        "/v1/fleets/me/trucks/00000000-0000-0000-0000-000000000000", headers=AUTH_CUSTOMER
    )
    assert response.status_code == 404
