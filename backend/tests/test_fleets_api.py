"""FLT-1 tests: fleet CRUD (create own fleet, view it, attach/detach trucks).

FLT-4's invite tests live at the bottom (create invite + the fleet-owner side of
409s); the driver-side redemption tests (POST /v1/drivers/me/register with an
invite_token) live in tests/test_drivers_api.py, next to the rest of registration.
"""

import uuid
from typing import Any

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import Truck, TruckCapacity, TruckType
from app.models.fleet import DriverInvite, InviteStatus
from app.models.user import User, UserRole
from tests.conftest import FakeRedis, _create_user, make_available_driver

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


async def test_fleet_trucks_show_live_driver_status_and_name(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    """FLT-3 ('Mi flota' at-a-glance status) needs this on every truck --
    neither driver status nor name lives on Truck itself."""
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Grúas del Poblado"})

    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-status-driver", plate="FLTSTAT1"
    )
    async with session_maker() as session:
        truck = (await session.scalars(select(Truck).where(Truck.driver_id == driver.id))).one()

    add = await client.post(f"/v1/fleets/me/trucks/{truck.id}", headers=AUTH_CUSTOMER)
    assert add.status_code == 200
    truck_body = add.json()["trucks"][0]
    assert truck_body["driver_status"] == "available"
    assert truck_body["driver_name"] == driver.name

    # A driver with no driver_profile row (never registered via AUTH-5's
    # /register, e.g. _register_driver_truck's bare seed) has no status to
    # show, but the truck still has a real driver_id/name.
    unassigned = await _register_driver_truck(
        session_maker, firebase_uid="unassigned-status-driver", plate="FLTSTAT2"
    )
    add2 = await client.post(f"/v1/fleets/me/trucks/{unassigned.id}", headers=AUTH_CUSTOMER)
    assert add2.status_code == 200
    unassigned_body = next(t for t in add2.json()["trucks"] if t["id"] == str(unassigned.id))
    assert unassigned_body["driver_status"] is None
    assert unassigned_body["driver_name"] == "D"


async def test_find_truck_by_plate(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    """FLT-4: a fleet owner knows a driver's plate, not their truck's UUID."""
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    truck = await _register_driver_truck(
        session_maker, firebase_uid="lookup-driver", plate="LOOKUP1"
    )

    found = await client.get("/v1/fleets/trucks/by-plate/LOOKUP1", headers=AUTH_CUSTOMER)
    assert found.status_code == 200
    assert found.json()["id"] == str(truck.id)

    missing = await client.get("/v1/fleets/trucks/by-plate/NOPE999", headers=AUTH_CUSTOMER)
    assert missing.status_code == 404


# ---- FLT-4: POST /v1/fleets/me/invites -----------------------------------------


def _invite_body(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "phone": "+573009998877",
        "plate": "INV0001",
        "truck_type": "car",
        "capacity": "car",
    }
    body.update(overrides)
    return body


async def test_create_invite_pre_provisions_truck(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    create_fleet = await client.post(
        "/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Grúas del Poblado"}
    )
    assert create_fleet.status_code == 201
    fleet_id = create_fleet.json()["id"]

    response = await client.post(
        "/v1/fleets/me/invites", headers=AUTH_CUSTOMER, json=_invite_body()
    )
    assert response.status_code == 201
    body = response.json()
    assert body["phone"] == "+573009998877"
    assert "invite_token" in body
    assert "truck_id" in body

    async with session_maker() as session:
        truck = await session.get(Truck, uuid.UUID(body["truck_id"]))
        assert truck is not None
        assert truck.plate == "INV0001"
        assert truck.type is TruckType.car
        assert truck.capacity is TruckCapacity.car
        assert truck.driver_id is None
        assert str(truck.fleet_id) == fleet_id

        invite = await session.scalar(
            select(DriverInvite).where(DriverInvite.token == uuid.UUID(body["invite_token"]))
        )
        assert invite is not None
        assert invite.status is InviteStatus.pending
        assert str(invite.truck_id) == body["truck_id"]

    listed = await client.get("/v1/fleets/me/invites", headers=AUTH_CUSTOMER)
    assert listed.status_code == 200
    assert [i["invite_token"] for i in listed.json()] == [body["invite_token"]]


async def test_create_invite_duplicate_pending_phone_is_409(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet A"})

    first = await client.post(
        "/v1/fleets/me/invites", headers=AUTH_CUSTOMER, json=_invite_body(plate="INV0002")
    )
    assert first.status_code == 201

    second = await client.post(
        "/v1/fleets/me/invites", headers=AUTH_CUSTOMER, json=_invite_body(plate="INV0003")
    )
    assert second.status_code == 409


async def test_create_invite_duplicate_plate_is_409(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    await client.post("/v1/fleets/me", headers=AUTH_CUSTOMER, json={"name": "Fleet A"})

    await _register_driver_truck(session_maker, firebase_uid="unused", plate="INV0004")

    response = await client.post(
        "/v1/fleets/me/invites",
        headers=AUTH_CUSTOMER,
        json=_invite_body(phone="+573001112222", plate="INV0004"),
    )
    assert response.status_code == 409


async def test_create_invite_without_fleet_is_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post(
        "/v1/fleets/me/invites", headers=AUTH_CUSTOMER, json=_invite_body()
    )
    assert response.status_code == 404
