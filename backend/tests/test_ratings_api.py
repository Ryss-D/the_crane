"""RAT-1 tests: both-direction ratings, completion/duplicate/actor guards, rating_avg
recomputation, and GET-ratings visibility."""

from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverProfile, DriverStatus
from app.models.job import JobStatus
from app.models.user import User, UserRole
from tests.conftest import _create_user, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}
AUTH_DRIVER = {"Authorization": "Bearer driver-token"}
AUTH_ADMIN = {"Authorization": "Bearer admin-token"}
AUTH_OTHER = {"Authorization": "Bearer other-token"}


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


async def _make_driver_profile(
    session_maker: async_sessionmaker[AsyncSession], driver: User
) -> None:
    async with session_maker() as session:
        session.add(DriverProfile(user_id=driver.id, status=DriverStatus.offline, verified=True))
        await session.commit()


async def _driver_rating_avg(
    session_maker: async_sessionmaker[AsyncSession], driver: User
) -> float | None:
    async with session_maker() as session:
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == driver.id)
        )
        assert profile is not None
        return float(profile.rating_avg) if profile.rating_avg is not None else None


async def test_rate_completed_job_both_directions(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )

    response = await client.post(
        f"/v1/jobs/{job.id}/rating",
        headers=AUTH_CUSTOMER,
        json={"stars": 5, "comment": "Great service"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["from_user_id"] == str(customer_user.id)
    assert body["to_user_id"] == str(driver_user.id)
    assert body["stars"] == 5
    assert body["comment"] == "Great service"

    response = await client.post(
        f"/v1/jobs/{job.id}/rating",
        headers=AUTH_DRIVER,
        json={"stars": 4},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["from_user_id"] == str(driver_user.id)
    assert body["to_user_id"] == str(customer_user.id)
    assert body["comment"] is None

    assert await _driver_rating_avg(session_maker, driver_user) == 5.0

    for headers in (AUTH_CUSTOMER, AUTH_DRIVER, AUTH_ADMIN):
        response = await client.get(f"/v1/jobs/{job.id}/ratings", headers=headers)
        assert response.status_code == 200
        items = response.json()["items"]
        assert len(items) == 2
        stars = {item["from_user_id"]: item["stars"] for item in items}
        assert stars[str(customer_user.id)] == 5
        assert stars[str(driver_user.id)] == 4


async def test_rate_before_completed_is_409(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.in_transit
    )

    response = await client.post(
        f"/v1/jobs/{job.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 5}
    )
    assert response.status_code == 409


async def test_duplicate_rating_is_409(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )

    first = await client.post(f"/v1/jobs/{job.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 3})
    assert first.status_code == 201

    second = await client.post(
        f"/v1/jobs/{job.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 1}
    )
    assert second.status_code == 409


async def test_wrong_actor_is_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    other = await _create_user(session_maker, "other-uid", UserRole.customer)
    verified_tokens["other-token"] = {"uid": other.firebase_uid}

    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )

    response = await client.post(f"/v1/jobs/{job.id}/rating", headers=AUTH_OTHER, json={"stars": 5})
    assert response.status_code == 403


async def test_rating_avg_recomputes_over_multiple_jobs(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    await _make_driver_profile(session_maker, driver_user)
    job_a = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )
    job_b = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )

    resp_a = await client.post(
        f"/v1/jobs/{job_a.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 5}
    )
    assert resp_a.status_code == 201
    assert await _driver_rating_avg(session_maker, driver_user) == 5.0

    resp_b = await client.post(
        f"/v1/jobs/{job_b.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 3}
    )
    assert resp_b.status_code == 201
    assert await _driver_rating_avg(session_maker, driver_user) == 4.0


async def test_ratings_visibility_unrelated_user_is_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    other = await _create_user(session_maker, "other-uid", UserRole.customer)
    verified_tokens["other-token"] = {"uid": other.firebase_uid}

    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )
    await client.post(f"/v1/jobs/{job.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 5})

    response = await client.get(f"/v1/jobs/{job.id}/ratings", headers=AUTH_OTHER)
    assert response.status_code == 403


async def test_rating_stars_out_of_range_is_422(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    await _make_driver_profile(session_maker, driver_user)
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.completed
    )
    response = await client.post(
        f"/v1/jobs/{job.id}/rating", headers=AUTH_CUSTOMER, json={"stars": 6}
    )
    assert response.status_code == 422
