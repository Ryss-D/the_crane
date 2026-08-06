"""JOB-5 tests: create-from-quote (snapshot), get/list permissions, cancel, track."""

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverProfile, Truck, TruckCapacity, TruckType
from app.models.job import DriverLocationSnapshot, Job, JobStatus
from app.models.user import User, UserRole
from app.services.config import set_config
from app.services.jobs import get_job_event_hook
from app.services.pricing import get_directions_client
from tests.conftest import FakeRedis, _create_user, make_available_driver, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}
AUTH_DRIVER = {"Authorization": "Bearer driver-token"}
AUTH_ADMIN = {"Authorization": "Bearer admin-token"}
AUTH_OTHER = {"Authorization": "Bearer other-token"}


class FixedDirections:
    async def road_distance_km(
        self, pickup: tuple[float, float], dropoff: tuple[float, float]
    ) -> float:
        return 10.0


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    driver_user: User,
    admin_user: User,
) -> dict[str, dict[str, Any]]:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["driver-token"] = {"uid": driver_user.firebase_uid}
    verified_tokens["admin-token"] = {"uid": admin_user.firebase_uid}
    return verified_tokens


def _job_body(quote_id: str, vehicle_type: str = "car") -> dict[str, Any]:
    return {
        "quote_id": quote_id,
        "vehicle_type": vehicle_type,
        "pickup": {"lat": 6.2442, "lng": -75.5812, "address": "Calle 10 # 43-12"},
        "dropoff": {"lat": 6.2000, "lng": -75.5700, "address": "Carrera 70 # 1-141"},
    }


async def _get_quote(app: FastAPI, client: AsyncClient, vehicle_type: str = "car") -> dict:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections()
    response = await client.post(
        "/v1/jobs/quote",
        headers=AUTH_CUSTOMER,
        json={
            "vehicle_type": vehicle_type,
            "pickup": {"lat": 6.2442, "lng": -75.5812},
            "dropoff": {"lat": 6.2000, "lng": -75.5700},
        },
    )
    assert response.status_code == 200
    return response.json()


async def test_create_job_from_quote(
    app: FastAPI,
    client: AsyncClient,
    tokens: dict,
    seeded_config: dict[str, Any],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    # DSP-2 now runs synchronously on job creation: seed one reachable driver so the
    # job lands (and stays) in `matching` with a pending offer, instead of exhausting
    # straight to `no_drivers` for lack of any candidate.
    await make_available_driver(session_maker, fake_redis, firebase_uid="dispatch-driver-1")

    events: list[tuple[JobStatus, JobStatus]] = []

    async def hook(job: Any, old: JobStatus, new: JobStatus) -> None:
        events.append((old, new))

    app.dependency_overrides[get_job_event_hook] = lambda: hook
    quote = await _get_quote(app, client)
    response = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "matching"
    assert body["quoted_price"] == quote["price"]
    assert body["distance_km"] == quote["distance_km"]
    assert body["share_token"]
    assert body["config_snapshot"]["pricing"] == seeded_config["pricing"]
    assert body["config_snapshot"]["commission"] == seeded_config["commission"]
    assert events == [(JobStatus.requested, JobStatus.matching)]


async def test_create_job_snapshot_survives_config_change(
    app: FastAPI,
    client: AsyncClient,
    tokens: dict,
    seeded_config: dict[str, Any],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    quote = await _get_quote(app, client)
    created = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    assert created.status_code == 201
    job_id = created.json()["id"]

    async with session_maker() as session:
        await set_config(
            session, fake_redis, "pricing", {"car": {"base": 1, "per_km": 1, "min": 1}}
        )
        await set_config(session, fake_redis, "commission", {"mode": "flat", "amount": {"car": 5}})

    fetched = await client.get(f"/v1/jobs/{job_id}", headers=AUTH_CUSTOMER)
    snapshot = fetched.json()["config_snapshot"]
    assert snapshot["pricing"] == seeded_config["pricing"]  # frozen at creation
    assert snapshot["commission"] == seeded_config["commission"]


async def test_create_job_unknown_or_expired_quote_410(
    app: FastAPI,
    client: AsyncClient,
    tokens: dict,
    seeded_config: dict[str, Any],
    fake_redis: FakeRedis,
) -> None:
    bogus = str(uuid.uuid4())
    response = await client.post("/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(bogus))
    assert response.status_code == 410

    # Simulate TTL expiry: the cached quote vanished from Redis.
    quote = await _get_quote(app, client)
    fake_redis.store.clear()
    response = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    assert response.status_code == 410


async def test_create_job_quote_is_single_use(
    app: FastAPI, client: AsyncClient, tokens: dict, seeded_config: dict[str, Any]
) -> None:
    quote = await _get_quote(app, client)
    first = await client.post("/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"]))
    second = await client.post("/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"]))
    assert first.status_code == 201
    assert second.status_code == 410


async def test_create_job_vehicle_type_must_match_quote(
    app: FastAPI, client: AsyncClient, tokens: dict, seeded_config: dict[str, Any]
) -> None:
    quote = await _get_quote(app, client, vehicle_type="moto")
    response = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"], vehicle_type="car")
    )
    assert response.status_code == 409


async def test_get_job_permission_matrix(
    client: AsyncClient,
    tokens: dict,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    other = await _create_user(session_maker, "other-uid", UserRole.customer)
    verified_tokens["other-token"] = {"uid": other.firebase_uid}
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )

    assert (await client.get(f"/v1/jobs/{job.id}", headers=AUTH_CUSTOMER)).status_code == 200
    assert (await client.get(f"/v1/jobs/{job.id}", headers=AUTH_DRIVER)).status_code == 200
    assert (await client.get(f"/v1/jobs/{job.id}", headers=AUTH_ADMIN)).status_code == 200
    assert (await client.get(f"/v1/jobs/{job.id}", headers=AUTH_OTHER)).status_code == 403

    missing = await client.get(f"/v1/jobs/{uuid.uuid4()}", headers=AUTH_CUSTOMER)
    assert missing.status_code == 404


async def test_list_jobs_paginated_newest_first(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    now = datetime.now(UTC)
    jobs = [
        await make_job(
            session_maker,
            customer_user,
            status=JobStatus.completed,
            requested_at=now - timedelta(hours=3 - i),
        )
        for i in range(3)
    ]
    response = await client.get(
        "/v1/jobs", headers=AUTH_CUSTOMER, params={"role": "customer", "limit": 2, "offset": 0}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 3
    assert [item["id"] for item in body["items"]] == [str(jobs[2].id), str(jobs[1].id)]

    page_two = await client.get(
        "/v1/jobs", headers=AUTH_CUSTOMER, params={"role": "customer", "limit": 2, "offset": 2}
    )
    assert [item["id"] for item in page_two.json()["items"]] == [str(jobs[0].id)]


async def test_list_jobs_driver_role_sees_only_assigned(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    assigned = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    await make_job(session_maker, customer_user, status=JobStatus.matching)  # unassigned

    response = await client.get("/v1/jobs", headers=AUTH_DRIVER, params={"role": "driver"})
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(assigned.id)

    as_customer = await client.get("/v1/jobs", headers=AUTH_DRIVER, params={"role": "customer"})
    assert as_customer.json()["total"] == 0


async def test_cancel_endpoint_matrix(
    client: AsyncClient,
    tokens: dict,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    other = await _create_user(session_maker, "other-uid", UserRole.customer)
    verified_tokens["other-token"] = {"uid": other.firebase_uid}

    # Customer cancel while matching -> cancelled.
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    response = await client.post(f"/v1/jobs/{job.id}/cancel", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"

    # Driver cancel -> back to matching, driver released. DSP-2 re-dispatches
    # synchronously on this edge, so seed a standby driver to land back in
    # `matching` (with a fresh pending offer to them) instead of `no_drivers`.
    await make_available_driver(session_maker, fake_redis, firebase_uid="dispatch-standby")
    job = await make_job(
        session_maker, customer_user, status=JobStatus.en_route_pickup, driver=driver_user
    )
    response = await client.post(f"/v1/jobs/{job.id}/cancel", headers=AUTH_DRIVER)
    assert response.status_code == 200
    assert response.json()["status"] == "matching"
    assert response.json()["driver_id"] is None

    # Stranger -> 403; customer too late -> 409.
    job = await make_job(
        session_maker, customer_user, status=JobStatus.in_transit, driver=driver_user
    )
    assert (await client.post(f"/v1/jobs/{job.id}/cancel", headers=AUTH_OTHER)).status_code == 403
    assert (
        await client.post(f"/v1/jobs/{job.id}/cancel", headers=AUTH_CUSTOMER)
    ).status_code == 409


async def test_track_public_no_auth_and_pii_limits(
    client: AsyncClient,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    async with session_maker() as session:
        session.add(
            Truck(
                plate="ABC123",
                type=TruckType.car,
                capacity=TruckCapacity.car,
                driver_id=driver_user.id,
            )
        )
        await session.commit()
    job = await make_job(
        session_maker, customer_user, status=JobStatus.en_route_pickup, driver=driver_user
    )
    async with session_maker() as session:
        session.add(
            DriverLocationSnapshot(
                job_id=job.id,
                driver_id=driver_user.id,
                lat=6.23,
                lng=-75.58,
                job_status=JobStatus.en_route_pickup,
            )
        )
        await session.commit()

    response = await client.get(f"/v1/track/{job.share_token}")  # NO auth header
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "en_route_pickup"
    assert body["pickup"] == {"lat": job.pickup_lat, "lng": job.pickup_lng}
    assert body["driver"] == {"first_name": "Test", "truck_plate": "ABC123"}
    assert body["driver_location"] == {"lat": 6.23, "lng": -75.58}
    # PII limits: no phone, no prices, no customer data, no full name.
    assert set(body.keys()) == {"status", "pickup", "dropoff", "driver", "driver_location"}
    assert "phone" not in body["driver"]


async def test_track_before_assignment_hides_driver(
    client: AsyncClient,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    response = await client.get(f"/v1/track/{job.share_token}")
    assert response.status_code == 200
    assert response.json()["driver"] is None
    assert response.json()["driver_location"] is None


async def test_track_unknown_token_404(client: AsyncClient) -> None:
    assert (await client.get(f"/v1/track/{uuid.uuid4()}")).status_code == 404
    assert (await client.get("/v1/track/not-a-uuid")).status_code == 404


async def test_track_expires_24h_after_completion(
    client: AsyncClient, session_maker: async_sessionmaker[AsyncSession], customer_user: User
) -> None:
    """TRK-6's AC: the share link works logged-out but expires 24h after the
    job ends -- it's not a link a customer can hand out forever."""
    job = await make_job(session_maker, customer_user, status=JobStatus.completed)
    async with session_maker() as session:
        db_job = await session.get(Job, job.id)
        assert db_job is not None
        db_job.completed_at = datetime.now(UTC) - timedelta(hours=23)
        await session.commit()
    fresh = await client.get(f"/v1/track/{job.share_token}")
    assert fresh.status_code == 200

    async with session_maker() as session:
        db_job = await session.get(Job, job.id)
        assert db_job is not None
        db_job.completed_at = datetime.now(UTC) - timedelta(hours=25)
        await session.commit()
    stale = await client.get(f"/v1/track/{job.share_token}")
    assert stale.status_code == 404


async def test_assigned_job_embeds_driver_summary(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    fake_redis: FakeRedis,
) -> None:
    """The customer/driver apps (CUS-3's driver card, WEB-3's driver card) have
    always expected `driver` on an assigned job -- nothing populated it until now
    (`JobRead.driver` + `_job_read` in app/api/jobs.py)."""
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="summary-driver", plate="ABC999"
    )
    async with session_maker() as session:
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == driver.id)
        )
        assert profile is not None
        profile.rating_avg = Decimal("4.90")
        await session.commit()

    job = await make_job(session_maker, customer_user, status=JobStatus.assigned, driver=driver)

    response = await client.get(f"/v1/jobs/{job.id}", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    body = response.json()["driver"]
    assert body["id"] == str(driver.id)
    assert body["truck_plate"] == "ABC999"
    assert body["truck_type"] == "car"
    assert body["rating_avg"] == 4.9


async def test_unassigned_job_has_no_driver_summary(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    response = await client.get(f"/v1/jobs/{job.id}", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    assert response.json()["driver"] is None
