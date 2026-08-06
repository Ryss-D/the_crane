"""FLT-2 tests: fleet ledger rollup + consolidated settlement.

Covers: GET /v1/fleets/me/balance and GET /v1/admin/fleets/{id}/balance (rollup
equals sum of member driver balances), POST /v1/admin/fleets/{id}/settle (one
payment apportioned across member drivers' ledgers), and the balance-cap gate in
PATCH /v1/drivers/me/status evaluating at fleet level for fleet drivers.
"""

from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverStatus, Truck
from app.models.fleet import Fleet
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.user import User, UserRole
from app.services.config import set_config
from app.services.ledger import driver_owed_balance, fleet_owed_balance
from tests.conftest import FakeRedis, _create_user, make_available_driver

AUTH_ADMIN = {"Authorization": "Bearer admin-token"}


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]],
    admin_user: User,
) -> dict[str, dict[str, Any]]:
    verified_tokens["admin-token"] = {"uid": admin_user.firebase_uid}
    return verified_tokens


async def _make_fleet(
    session_maker: async_sessionmaker[AsyncSession], *, owner_firebase_uid: str
) -> Fleet:
    owner = await _create_user(session_maker, owner_firebase_uid, UserRole.fleet_owner)
    async with session_maker() as session:
        fleet = Fleet(owner_user_id=owner.id, name="Test Fleet")
        session.add(fleet)
        await session.commit()
        await session.refresh(fleet)
        return fleet


async def _attach_truck(
    session_maker: async_sessionmaker[AsyncSession], driver: User, fleet: Fleet
) -> None:
    async with session_maker() as session:
        truck = await session.scalar(select(Truck).where(Truck.driver_id == driver.id))
        assert truck is not None
        truck.fleet_id = fleet.id
        await session.commit()


async def _add_earning(
    session_maker: async_sessionmaker[AsyncSession], driver: User, commission: int
) -> None:
    async with session_maker() as session:
        session.add(
            DriverLedgerEntry(
                driver_id=driver.id,
                job_id=None,
                gross=commission * 7,
                commission=commission,
                net=commission * 6,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()


async def test_fleet_balance_equals_sum_of_member_balances(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-1")
    driver_a = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-a", status=DriverStatus.offline
    )
    driver_b = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-b", status=DriverStatus.offline
    )
    await _attach_truck(session_maker, driver_a, fleet)
    await _attach_truck(session_maker, driver_b, fleet)
    await _add_earning(session_maker, driver_a, 15000)
    await _add_earning(session_maker, driver_b, 9000)

    async with session_maker() as session:
        expected = (await driver_owed_balance(session, driver_a.id)) + (
            await driver_owed_balance(session, driver_b.id)
        )
        rollup = await fleet_owed_balance(session, fleet.id)
    assert expected == 24000
    assert rollup == expected

    response = await client.get(f"/v1/admin/fleets/{fleet.id}/balance", headers=AUTH_ADMIN)
    assert response.status_code == 200
    body = response.json()
    assert body["owed_balance"] == expected
    assert {m["driver_id"] for m in body["members"]} == {str(driver_a.id), str(driver_b.id)}


async def test_fleet_balance_404_for_unknown_fleet(
    client: AsyncClient, tokens: dict[str, dict[str, Any]]
) -> None:
    response = await client.get(
        "/v1/admin/fleets/00000000-0000-0000-0000-000000000000/balance", headers=AUTH_ADMIN
    )
    assert response.status_code == 404


async def test_list_fleets_shows_owner_truck_count_and_balance(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-list")
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-list", status=DriverStatus.offline
    )
    await _attach_truck(session_maker, driver, fleet)
    await _add_earning(session_maker, driver, 8000)

    response = await client.get("/v1/admin/fleets", headers=AUTH_ADMIN)
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 1
    item = items[0]
    assert item["id"] == str(fleet.id)
    assert item["owner_user_id"] == str(fleet.owner_user_id)
    assert item["name"] == "Test Fleet"
    assert item["truck_count"] == 1
    assert item["owed_balance"] > 0


async def test_list_fleets_empty_when_none_exist(
    client: AsyncClient, tokens: dict[str, dict[str, Any]]
) -> None:
    response = await client.get("/v1/admin/fleets", headers=AUTH_ADMIN)
    assert response.status_code == 200
    assert response.json() == []


async def test_settle_fleet_apportions_and_sums_to_amount(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-2")
    driver_a = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-c", status=DriverStatus.offline
    )
    driver_b = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-d", status=DriverStatus.offline
    )
    await _attach_truck(session_maker, driver_a, fleet)
    await _attach_truck(session_maker, driver_b, fleet)
    # 2:1 owed ratio -- an odd total amount forces the largest-remainder rounding.
    await _add_earning(session_maker, driver_a, 20000)
    await _add_earning(session_maker, driver_b, 10000)

    response = await client.post(
        f"/v1/admin/fleets/{fleet.id}/settle",
        headers=AUTH_ADMIN,
        json={"amount": 10001, "note": "weekly consolidated settlement"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["total_amount"] == 10001
    assert sum(e["amount"] for e in body["entries"]) == 10001
    by_driver = {e["driver_id"]: e["amount"] for e in body["entries"]}
    # 2:1 ratio of 10001 -> 6667/3334 by largest remainder (6667.33.. / 3333.67..).
    assert by_driver[str(driver_a.id)] == 6667
    assert by_driver[str(driver_b.id)] == 3334

    async with session_maker() as session:
        owed_a = await driver_owed_balance(session, driver_a.id)
        owed_b = await driver_owed_balance(session, driver_b.id)
    assert owed_a == 20000 - 6667
    assert owed_b == 10000 - 3334
    assert (owed_a + owed_b) == 20000 + 10000 - 10001


async def test_settle_fleet_rejects_non_positive_amount(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-3")
    response = await client.post(
        f"/v1/admin/fleets/{fleet.id}/settle", headers=AUTH_ADMIN, json={"amount": 0}
    )
    assert response.status_code == 422


async def test_settle_fleet_with_no_drivers_is_409(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-4")
    response = await client.post(
        f"/v1/admin/fleets/{fleet.id}/settle", headers=AUTH_ADMIN, json={"amount": 5000}
    )
    assert response.status_code == 409


async def test_fleet_settlement_unblocks_all_capped_members(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    """Each driver is individually under the cap, but their combined fleet balance
    is over it -- both should be blocked, and settling the fleet once unblocks both
    (FLT-2 AC: 'one fleet settlement unblocks all capped members')."""
    fleet = await _make_fleet(session_maker, owner_firebase_uid="fleet-owner-5")
    driver_a = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-e", status=DriverStatus.offline
    )
    driver_b = await make_available_driver(
        session_maker, fake_redis, firebase_uid="fleet-drv-f", status=DriverStatus.offline
    )
    await _attach_truck(session_maker, driver_a, fleet)
    await _attach_truck(session_maker, driver_b, fleet)
    async with session_maker() as session:
        await set_config(
            session, fake_redis, "settlement", {"balance_cap": 15000, "period": "weekly"}
        )
    await _add_earning(session_maker, driver_a, 8000)
    await _add_earning(session_maker, driver_b, 8000)  # each under 15000 alone; 16000 combined

    driver_a_token = {"Authorization": "Bearer fleet-drv-e-status-token"}
    driver_b_token = {"Authorization": "Bearer fleet-drv-f-status-token"}
    verified_tokens = tokens
    verified_tokens["fleet-drv-e-status-token"] = {"uid": driver_a.firebase_uid}
    verified_tokens["fleet-drv-f-status-token"] = {"uid": driver_b.firebase_uid}

    for headers in (driver_a_token, driver_b_token):
        response = await client.patch(
            "/v1/drivers/me/status",
            headers=headers,
            json={"status": "available", "lat": 6.2442, "lng": -75.5812},
        )
        assert response.status_code == 403

    settle = await client.post(
        f"/v1/admin/fleets/{fleet.id}/settle", headers=AUTH_ADMIN, json={"amount": 16000}
    )
    assert settle.status_code == 201

    for headers in (driver_a_token, driver_b_token):
        response = await client.patch(
            "/v1/drivers/me/status",
            headers=headers,
            json={"status": "available", "lat": 6.2442, "lng": -75.5812},
        )
        assert response.status_code == 200


async def test_independent_driver_cap_gating_unaffected_by_fleets(
    client: AsyncClient,
    tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    """A driver with no fleet still gates on their own balance alone."""
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="solo-drv", status=DriverStatus.offline
    )
    async with session_maker() as session:
        await set_config(
            session, fake_redis, "settlement", {"balance_cap": 5000, "period": "weekly"}
        )
    await _add_earning(session_maker, driver, 6000)

    verified_tokens = tokens
    verified_tokens["solo-drv-status-token"] = {"uid": driver.firebase_uid}
    response = await client.patch(
        "/v1/drivers/me/status",
        headers={"Authorization": "Bearer solo-drv-status-token"},
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert response.status_code == 403
