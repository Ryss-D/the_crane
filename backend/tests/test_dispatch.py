"""DSP-2..5 tests: sequential offer engine, accept/reject/retry, timeout sweep."""

import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import FastAPI
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverProfile, DriverStatus, TruckCapacity
from app.models.job import Job, JobOffer, JobStatus, OfferResponse, VehicleType
from app.models.user import User, UserRole
from app.services import dispatch
from app.services.config import set_config
from app.services.jobs import get_job_event_hook
from app.services.pricing import get_directions_client
from app.workers.offer_expiry import sweep_expired_offers
from tests.conftest import FakeRedis, _create_user, make_available_driver, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}


def _driver_token(firebase_uid: str) -> str:
    return f"{firebase_uid}-token"


def _driver_auth(firebase_uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {_driver_token(firebase_uid)}"}


class FixedDirections:
    async def road_distance_km(
        self, pickup: tuple[float, float], dropoff: tuple[float, float]
    ) -> float:
        return 10.0


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


async def test_create_job_triggers_first_offer_automatically(
    app: FastAPI,
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    seeded_config: dict[str, Any],
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="auto-offer-driver"
    )

    quote = await _get_quote(app, client)
    response = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    assert response.status_code == 201
    job_id = uuid.UUID(response.json()["id"])

    async with session_maker() as session:
        offer = await session.scalar(select(JobOffer).where(JobOffer.job_id == job_id))
    assert offer is not None
    assert offer.driver_id == driver.id
    assert offer.response is OfferResponse.pending


async def test_start_dispatch_offers_nearest_first(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    near = await make_available_driver(
        session_maker, fake_redis, firebase_uid="near", lat=6.2442, lng=-75.5812
    )
    await make_available_driver(session_maker, fake_redis, firebase_uid="far", lat=6.34, lng=-75.68)

    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())

    assert offer is not None
    assert offer.driver_id == near.id


async def test_driver_geo_position_returns_stored_lat_lng(fake_redis: FakeRedis) -> None:
    """DRV-2: GEOPOS lookup against the bucket the driver's capacity was added to."""
    driver_id = uuid.uuid4()
    await dispatch.add_driver_to_geo(fake_redis, driver_id, TruckCapacity.car, 6.25, -75.59)

    position = await dispatch.driver_geo_position(fake_redis, VehicleType.car, driver_id)

    assert position == (6.25, -75.59)


async def test_driver_geo_position_is_none_when_driver_not_in_geo_set(
    fake_redis: FakeRedis,
) -> None:
    """DRV-2: no GEOADD for this driver -> None, not an error (the enrichment must
    never be able to break an offer going out)."""
    position = await dispatch.driver_geo_position(fake_redis, VehicleType.car, uuid.uuid4())

    assert position is None


async def test_moto_job_never_offered_to_car_only_driver(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    # car_only sits right at the pickup point (closest possible); moto_only is
    # farther away but is the only one who can actually take a moto job.
    await make_available_driver(
        session_maker, fake_redis, firebase_uid="car-only", capacity=TruckCapacity.car
    )
    moto_only = await make_available_driver(
        session_maker,
        fake_redis,
        firebase_uid="moto-only",
        capacity=TruckCapacity.moto,
        lat=6.28,
        lng=-75.60,
    )

    job = await make_job(
        session_maker, customer_user, status=JobStatus.matching, vehicle_type=VehicleType.moto
    )
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())

    assert offer is not None
    assert offer.driver_id == moto_only.id


async def test_radius_widens_once_before_offering(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
) -> None:
    async with session_maker() as session:
        await set_config(
            session,
            fake_redis,
            "dispatch",
            {
                "offer_ttl_seconds": 30,
                "search_radius_km": 1,
                "radius_widen_factor": 3,
                "cancel_grace_seconds": 60,
                "rejection_cooldown_minutes": 10,
            },
        )
    # ~0.02 deg lat ~= 2.2km: outside the 1km base radius, inside the 3km widened one.
    far = await make_available_driver(
        session_maker, fake_redis, firebase_uid="widen-driver", lat=6.2442 + 0.02, lng=-75.5812
    )

    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())

    assert offer is not None
    assert offer.driver_id == far.id


async def test_dispatch_exhaustion_marks_no_drivers(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())

    assert offer is None
    assert job.status is JobStatus.no_drivers


async def test_sequential_offer_full_trail_reject_timeout_accept(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    """DSP-2's headline AC: 3 drivers — first rejects, second times out (swept),
    third accepts — job assigned, driver on_job, offer trail complete."""
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    d1 = await make_available_driver(
        session_maker, fake_redis, firebase_uid="d1", lat=6.2442, lng=-75.5812
    )
    d2 = await make_available_driver(
        session_maker, fake_redis, firebase_uid="d2", lat=6.26, lng=-75.60
    )
    d3 = await make_available_driver(
        session_maker, fake_redis, firebase_uid="d3", lat=6.28, lng=-75.62
    )
    for d in (d1, d2, d3):
        verified_tokens[_driver_token(d.firebase_uid)] = {"uid": d.firebase_uid}

    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer1 = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer1 is not None
    assert offer1.driver_id == d1.id

    # d1 rejects -> d2 offered next.
    response = await client.post(f"/v1/jobs/{job.id}/reject", headers=_driver_auth(d1.firebase_uid))
    assert response.status_code == 200
    async with session_maker() as session:
        pending = await session.scalar(
            select(JobOffer).where(
                JobOffer.job_id == job.id, JobOffer.response == OfferResponse.pending
            )
        )
    assert pending is not None
    assert pending.driver_id == d2.id

    # d2 times out: age their offer past the TTL, then run the sweep.
    ttl = seeded_config["dispatch"]["offer_ttl_seconds"]
    async with session_maker() as session:
        offer2 = await session.scalar(
            select(JobOffer).where(JobOffer.job_id == job.id, JobOffer.driver_id == d2.id)
        )
        assert offer2 is not None
        offer2.offered_at = datetime.now(UTC) - timedelta(seconds=ttl + 5)
        await session.commit()
    expired_count = await sweep_expired_offers(session_maker, fake_redis)
    assert expired_count == 1

    async with session_maker() as session:
        pending = await session.scalar(
            select(JobOffer).where(
                JobOffer.job_id == job.id, JobOffer.response == OfferResponse.pending
            )
        )
    assert pending is not None
    assert pending.driver_id == d3.id

    # d3 accepts -> job assigned, driver on_job, removed from the geo set.
    response = await client.post(f"/v1/jobs/{job.id}/accept", headers=_driver_auth(d3.firebase_uid))
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "assigned"
    assert body["driver_id"] == str(d3.id)

    async with session_maker() as session:
        offers = (
            await session.scalars(
                select(JobOffer).where(JobOffer.job_id == job.id).order_by(JobOffer.offered_at)
            )
        ).all()
        by_driver = {o.driver_id: o.response for o in offers}
        assert by_driver[d1.id] is OfferResponse.rejected
        assert by_driver[d2.id] is OfferResponse.timeout
        assert by_driver[d3.id] is OfferResponse.accepted

        profile3 = await session.scalar(select(DriverProfile).where(DriverProfile.user_id == d3.id))
        assert profile3 is not None
        assert profile3.status is DriverStatus.on_job

    assert str(d3.id) not in fake_redis.geo.get("drivers:geo:car", {})


async def test_reject_without_pending_offer_is_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
) -> None:
    driver = await _create_user(session_maker, "no-offer-driver", UserRole.driver)
    verified_tokens[_driver_token(driver.firebase_uid)] = {"uid": driver.firebase_uid}
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)

    response = await client.post(
        f"/v1/jobs/{job.id}/reject", headers=_driver_auth(driver.firebase_uid)
    )
    assert response.status_code == 403

    response = await client.post(
        f"/v1/jobs/{job.id}/accept", headers=_driver_auth(driver.firebase_uid)
    )
    assert response.status_code == 403


async def test_accept_offer_expired_is_409(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    driver = await make_available_driver(session_maker, fake_redis, firebase_uid="expired-driver")
    verified_tokens[_driver_token(driver.firebase_uid)] = {"uid": driver.firebase_uid}
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer is not None

    ttl = seeded_config["dispatch"]["offer_ttl_seconds"]
    async with session_maker() as session:
        row = await session.scalar(select(JobOffer).where(JobOffer.id == offer.id))
        assert row is not None
        row.offered_at = datetime.now(UTC) - timedelta(seconds=ttl + 5)
        await session.commit()

    response = await client.post(
        f"/v1/jobs/{job.id}/accept", headers=_driver_auth(driver.firebase_uid)
    )
    assert response.status_code == 409


async def test_concurrent_accept_exactly_one_winner(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    """DSP-3's race AC: two acceptors racing for the same job -> exactly one wins.

    Two pending offers for the same job never happen through normal dispatch (only
    one offer is ever pending at a time) — this seeds that (otherwise-impossible)
    state directly to stress the actual safety net: the atomic conditional UPDATE
    in POST /accept, whose WHERE clause can only ever match once.
    """
    driver_a = await make_available_driver(session_maker, fake_redis, firebase_uid="race-a")
    driver_b = await make_available_driver(
        session_maker, fake_redis, firebase_uid="race-b", lat=6.25, lng=-75.59
    )
    verified_tokens[_driver_token(driver_a.firebase_uid)] = {"uid": driver_a.firebase_uid}
    verified_tokens[_driver_token(driver_b.firebase_uid)] = {"uid": driver_b.firebase_uid}

    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        session.add_all(
            [
                JobOffer(job_id=job.id, driver_id=driver_a.id, response=OfferResponse.pending),
                JobOffer(job_id=job.id, driver_id=driver_b.id, response=OfferResponse.pending),
            ]
        )
        await session.commit()

    results = await asyncio.gather(
        client.post(f"/v1/jobs/{job.id}/accept", headers=_driver_auth(driver_a.firebase_uid)),
        client.post(f"/v1/jobs/{job.id}/accept", headers=_driver_auth(driver_b.firebase_uid)),
    )
    status_codes = sorted(r.status_code for r in results)
    assert status_codes == [200, 409]

    async with session_maker() as session:
        refreshed = await session.get(Job, job.id)
        assert refreshed is not None
        assert refreshed.status is JobStatus.assigned
        assert refreshed.driver_id in (driver_a.id, driver_b.id)

        winner_offer = await session.scalar(
            select(JobOffer).where(
                JobOffer.job_id == job.id, JobOffer.driver_id == refreshed.driver_id
            )
        )
        assert winner_offer is not None
        assert winner_offer.response is OfferResponse.accepted


async def test_retry_excludes_recently_rejected_driver_until_cooldown_elapses(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    d1 = await make_available_driver(session_maker, fake_redis, firebase_uid="retry-d1")

    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer is not None
    assert offer.driver_id == d1.id

    async with session_maker() as session:
        job = await session.merge(job)
        await dispatch.advance_dispatch(
            session,
            fake_redis,
            job,
            driver_id=d1.id,
            response=OfferResponse.rejected,
            event_hook=get_job_event_hook(),
        )
    assert job.status is JobStatus.no_drivers

    # Retry right away: d1 rejected moments ago (within cooldown) -> stays excluded.
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.retry_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer is None
    assert job.status is JobStatus.no_drivers

    # Simulate the cooldown having elapsed.
    cooldown = seeded_config["dispatch"]["rejection_cooldown_minutes"]
    async with session_maker() as session:
        rejected_offer = await session.scalar(
            select(JobOffer).where(JobOffer.job_id == job.id, JobOffer.driver_id == d1.id)
        )
        assert rejected_offer is not None
        rejected_offer.responded_at = datetime.now(UTC) - timedelta(minutes=cooldown + 1)
        await session.commit()

    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.retry_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer is not None
    assert offer.driver_id == d1.id
    assert job.status is JobStatus.matching


async def test_retry_only_valid_from_no_drivers(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    response = await client.post(f"/v1/jobs/{job.id}/retry", headers=AUTH_CUSTOMER)
    assert response.status_code == 409


async def test_sweep_is_a_noop_when_nothing_is_stale(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    seeded_config: dict[str, Any],
) -> None:
    await make_available_driver(session_maker, fake_redis, firebase_uid="fresh-driver")
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        offer = await dispatch.start_dispatch(session, fake_redis, job, get_job_event_hook())
    assert offer is not None

    expired_count = await sweep_expired_offers(session_maker, fake_redis)
    assert expired_count == 0

    async with session_maker() as session:
        still_pending = await session.scalar(
            select(JobOffer).where(JobOffer.job_id == job.id, JobOffer.id == offer.id)
        )
        assert still_pending is not None
        assert still_pending.response is OfferResponse.pending
