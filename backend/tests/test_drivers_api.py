"""AUTH-5 + DSP-1 tests: driver registration, and availability/geo status.

FLT-4's invite-redemption tests live at the bottom -- POST /v1/drivers/me/register's
`invite_token` path, next to the rest of registration. The fleet-owner side (creating
an invite) is tested in tests/test_fleets_api.py.
"""

import uuid
from typing import Any

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverProfile, DriverStatus, Truck, TruckType
from app.models.fleet import DriverInvite, InviteStatus
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.user import User, UserRole
from app.services.config import set_config
from tests.conftest import FakeRedis, _create_user

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}


def _register_body(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "plate": "XYZ123",
        "truck_type": "car",
        "capacity": "car",
        "license_url": "https://example.com/license.jpg",
        "truck_photo_url": "https://example.com/truck.jpg",
    }
    body.update(overrides)
    return body


async def _register_and_verify(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    *,
    firebase_uid: str,
    plate: str,
    verified: bool = True,
) -> tuple[User, dict[str, str]]:
    """Register a driver through the real endpoint, then (optionally) flip verified
    directly in the DB — the admin verify endpoint is a separate (ADM) task."""
    user = await _create_user(session_maker, firebase_uid, UserRole.customer)
    token = f"{firebase_uid}-token"
    verified_tokens[token] = {"uid": user.firebase_uid}
    headers = {"Authorization": f"Bearer {token}"}
    response = await client.post(
        "/v1/drivers/me/register", headers=headers, json=_register_body(plate=plate)
    )
    assert response.status_code == 201
    if verified:
        async with session_maker() as session:
            profile = await session.scalar(
                select(DriverProfile).where(DriverProfile.user_id == user.id)
            )
            assert profile is not None
            profile.verified = True
            await session.commit()
    return user, headers


async def test_register_driver_creates_profile_and_truck_and_flips_role(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post(
        "/v1/drivers/me/register", headers=AUTH_CUSTOMER, json=_register_body()
    )
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "offline"
    assert body["verified"] is False
    assert body["truck"]["plate"] == "XYZ123"
    assert body["truck"]["capacity"] == "car"

    async with session_maker() as session:
        user = await session.get(User, customer_user.id)
        assert user is not None
        assert user.role is UserRole.driver
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == customer_user.id)
        )
        assert profile is not None
        assert profile.status is DriverStatus.offline
        truck = await session.scalar(select(Truck).where(Truck.driver_id == customer_user.id))
        assert truck is not None
        assert truck.type is TruckType.car


async def test_register_driver_twice_is_409(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    first = await client.post(
        "/v1/drivers/me/register", headers=AUTH_CUSTOMER, json=_register_body()
    )
    assert first.status_code == 201
    second = await client.post(
        "/v1/drivers/me/register", headers=AUTH_CUSTOMER, json=_register_body(plate="OTHER1")
    )
    assert second.status_code == 409


async def test_register_driver_duplicate_plate_409(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    other = await _create_user(session_maker, "other-driver-uid", UserRole.customer)
    verified_tokens["other-driver-token"] = {"uid": other.firebase_uid}

    first = await client.post(
        "/v1/drivers/me/register", headers=AUTH_CUSTOMER, json=_register_body(plate="DUPE01")
    )
    assert first.status_code == 201
    second = await client.post(
        "/v1/drivers/me/register",
        headers={"Authorization": "Bearer other-driver-token"},
        json=_register_body(plate="DUPE01"),
    )
    assert second.status_code == 409


async def test_status_requires_verification(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    _user, headers = await _register_and_verify(
        client,
        verified_tokens,
        session_maker,
        firebase_uid="unverified",
        plate="UNV001",
        verified=False,
    )
    response = await client.patch(
        "/v1/drivers/me/status",
        headers=headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert response.status_code == 403


async def test_status_available_requires_lat_lng(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    _user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="needs-latlng", plate="LL0001"
    )
    response = await client.patch(
        "/v1/drivers/me/status", headers=headers, json={"status": "available"}
    )
    assert response.status_code == 422


async def test_status_available_writes_geo_offline_removes(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="geo-driver", plate="GEO0001"
    )
    response = await client.patch(
        "/v1/drivers/me/status",
        headers=headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "available"
    assert str(user.id) in fake_redis.geo.get("drivers:geo:car", {})

    response = await client.patch(
        "/v1/drivers/me/status", headers=headers, json={"status": "offline"}
    )
    assert response.status_code == 200
    assert response.json()["status"] == "offline"
    assert str(user.id) not in fake_redis.geo.get("drivers:geo:car", {})


async def test_status_blocked_while_on_job(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="busy-driver", plate="BUSY001"
    )
    async with session_maker() as session:
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == user.id)
        )
        assert profile is not None
        profile.status = DriverStatus.on_job
        await session.commit()

    response = await client.patch(
        "/v1/drivers/me/status",
        headers=headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert response.status_code == 409


async def test_status_blocked_over_balance_cap(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="capped-driver", plate="CAP0001"
    )
    async with session_maker() as session:
        await set_config(
            session, fake_redis, "settlement", {"balance_cap": 10000, "period": "weekly"}
        )
        session.add(
            DriverLedgerEntry(
                driver_id=user.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()

    response = await client.patch(
        "/v1/drivers/me/status",
        headers=headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert response.status_code == 403


# ---- GET /v1/drivers/me/balance (DRV-5) ----------------------------------------


async def test_get_balance_reports_owed_and_recent_settlements(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="balance-driver", plate="BAL0001"
    )
    async with session_maker() as session:
        await set_config(
            session, fake_redis, "settlement", {"balance_cap": 50000, "period": "weekly"}
        )
        session.add(
            DriverLedgerEntry(
                driver_id=user.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        session.add(
            DriverLedgerEntry(
                driver_id=user.id,
                job_id=None,
                gross=5000,
                commission=0,
                net=5000,
                entry_type=LedgerEntryType.payout,
                note="partial settlement",
            )
        )
        await session.commit()

    response = await client.get("/v1/drivers/me/balance", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["owed_cents"] == 10000
    assert body["balance_cap_cents"] == 50000
    assert len(body["recent_settlements"]) == 1
    settlement = body["recent_settlements"][0]
    assert settlement["amount_cents"] == 5000
    assert settlement["note"] == "partial settlement"


async def test_get_balance_no_cap_and_no_settlements(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    _user, headers = await _register_and_verify(
        client, verified_tokens, session_maker, firebase_uid="fresh-driver", plate="FRESH01"
    )
    response = await client.get("/v1/drivers/me/balance", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["owed_cents"] == 0
    assert body["balance_cap_cents"] is None
    assert body["recent_settlements"] == []


async def test_get_balance_404_without_driver_profile(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get("/v1/drivers/me/balance", headers=AUTH_CUSTOMER)
    assert response.status_code == 404


# ---- FLT-4: POST /v1/drivers/me/register with invite_token --------------------


async def _create_invite_via_api(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    *,
    owner_firebase_uid: str,
    phone: str,
    plate: str,
) -> dict[str, Any]:
    """Create a fleet owner + fleet + invite through the real endpoints, the same
    way _register_and_verify above drives registration through the real endpoint."""
    owner = await _create_user(session_maker, owner_firebase_uid, UserRole.customer)
    token = f"{owner_firebase_uid}-token"
    verified_tokens[token] = {"uid": owner.firebase_uid}
    headers = {"Authorization": f"Bearer {token}"}
    create_fleet = await client.post("/v1/fleets/me", headers=headers, json={"name": "Fleet"})
    assert create_fleet.status_code == 201
    response = await client.post(
        "/v1/fleets/me/invites",
        headers=headers,
        json={"phone": phone, "plate": plate, "truck_type": "car", "capacity": "car"},
    )
    assert response.status_code == 201
    return response.json()


async def test_register_with_invite_links_existing_truck_and_consumes_invite(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    invite = await _create_invite_via_api(
        client,
        verified_tokens,
        session_maker,
        owner_firebase_uid="invite-owner",
        phone="+573005551234",
        plate="INVREG1",
    )
    verified_tokens["customer-token"] = {
        "uid": customer_user.firebase_uid,
        "phone_number": "+573005551234",
    }
    response = await client.post(
        "/v1/drivers/me/register",
        headers=AUTH_CUSTOMER,
        json={"invite_token": invite["invite_token"]},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["truck"]["id"] == invite["truck_id"]
    assert body["truck"]["plate"] == "INVREG1"

    async with session_maker() as session:
        truck = await session.get(Truck, uuid.UUID(invite["truck_id"]))
        assert truck is not None
        assert truck.driver_id == customer_user.id

        db_invite = await session.scalar(
            select(DriverInvite).where(DriverInvite.token == uuid.UUID(invite["invite_token"]))
        )
        assert db_invite is not None
        assert db_invite.status is InviteStatus.consumed
        assert db_invite.consumed_at is not None


async def test_register_with_invite_and_plate_is_422(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    invite = await _create_invite_via_api(
        client,
        verified_tokens,
        session_maker,
        owner_firebase_uid="invite-owner-2",
        phone="+573005551235",
        plate="INVREG2",
    )
    verified_tokens["customer-token"] = {
        "uid": customer_user.firebase_uid,
        "phone_number": "+573005551235",
    }
    response = await client.post(
        "/v1/drivers/me/register",
        headers=AUTH_CUSTOMER,
        json={"invite_token": invite["invite_token"], "plate": "SOMEPLT"},
    )
    assert response.status_code == 422


async def test_register_with_invite_phone_mismatch_is_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    invite = await _create_invite_via_api(
        client,
        verified_tokens,
        session_maker,
        owner_firebase_uid="invite-owner-3",
        phone="+573005551236",
        plate="INVREG3",
    )
    verified_tokens["customer-token"] = {
        "uid": customer_user.firebase_uid,
        "phone_number": "+573000000000",
    }
    response = await client.post(
        "/v1/drivers/me/register",
        headers=AUTH_CUSTOMER,
        json={"invite_token": invite["invite_token"]},
    )
    assert response.status_code == 403


async def test_register_with_invite_twice_is_409(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    invite = await _create_invite_via_api(
        client,
        verified_tokens,
        session_maker,
        owner_firebase_uid="invite-owner-4",
        phone="+573005551237",
        plate="INVREG4",
    )
    verified_tokens["customer-token"] = {
        "uid": customer_user.firebase_uid,
        "phone_number": "+573005551237",
    }
    first = await client.post(
        "/v1/drivers/me/register",
        headers=AUTH_CUSTOMER,
        json={"invite_token": invite["invite_token"]},
    )
    assert first.status_code == 201

    other = await _create_user(session_maker, "second-invitee", UserRole.customer)
    verified_tokens["second-invitee-token"] = {
        "uid": other.firebase_uid,
        "phone_number": "+573005551237",
    }
    second = await client.post(
        "/v1/drivers/me/register",
        headers={"Authorization": "Bearer second-invitee-token"},
        json={"invite_token": invite["invite_token"]},
    )
    assert second.status_code == 409


async def test_register_with_unknown_invite_token_is_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {
        "uid": customer_user.firebase_uid,
        "phone_number": "+573000000000",
    }
    response = await client.post(
        "/v1/drivers/me/register",
        headers=AUTH_CUSTOMER,
        json={"invite_token": "00000000-0000-0000-0000-000000000000"},
    )
    assert response.status_code == 404


async def test_register_without_plate_or_invite_is_422(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]], customer_user: User
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.post("/v1/drivers/me/register", headers=AUTH_CUSTOMER, json={})
    assert response.status_code == 422
