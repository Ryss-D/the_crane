"""JOB-3 service tests: transition legality, timestamps, snapshots, cancellation rules."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import DriverLocationSnapshot, Job, JobStatus
from app.models.user import User
from app.services.config import set_config
from app.services.jobs import (
    ALLOWED_TRANSITIONS,
    JobAccessError,
    JobTransitionError,
    cancel_job,
    transition,
)
from tests.conftest import FakeRedis, _create_user, make_job

LEGAL_TRANSITIONS = [
    (old, new) for old, targets in ALLOWED_TRANSITIONS.items() for new in sorted(targets)
]

_TIMESTAMPS = {
    JobStatus.assigned: "assigned_at",
    JobStatus.in_transit: "picked_up_at",
    JobStatus.completed: "completed_at",
    JobStatus.cancelled: "cancelled_at",
}


@pytest.mark.parametrize(("old", "new"), LEGAL_TRANSITIONS)
async def test_legal_transitions_move_and_stamp(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    old: JobStatus,
    new: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=old, driver=driver_user)
    async with session_maker() as session:
        job = await session.merge(job)
        await transition(session, job, new, actor=driver_user)
    assert job.status is new
    column = _TIMESTAMPS.get(new)
    if column is not None:
        assert getattr(job, column) is not None


async def test_illegal_transitions_raise_sweep(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    """Every (old, new) pair not in the map — including all terminal exits — is rejected."""
    checked = 0
    for old in JobStatus:
        for new in JobStatus:
            if new is old or new in ALLOWED_TRANSITIONS[old]:
                continue
            job = await make_job(session_maker, customer_user, status=old, driver=driver_user)
            async with session_maker() as session:
                job = await session.merge(job)
                with pytest.raises(JobTransitionError):
                    await transition(session, job, new, actor=driver_user)
            assert job.status is old
            checked += 1
    assert checked > 0


async def test_transition_writes_location_snapshot(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    async with session_maker() as session:
        job = await session.merge(job)
        await transition(
            session, job, JobStatus.en_route_pickup, actor=driver_user, lat=6.25, lng=-75.57
        )
        snapshot = await session.scalar(
            select(DriverLocationSnapshot).where(DriverLocationSnapshot.job_id == job.id)
        )
    assert snapshot is not None
    assert snapshot.driver_id == driver_user.id
    assert (snapshot.lat, snapshot.lng) == (6.25, -75.57)
    assert snapshot.job_status is JobStatus.en_route_pickup


async def test_transition_without_coords_writes_no_snapshot(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    async with session_maker() as session:
        job = await session.merge(job)
        await transition(session, job, JobStatus.en_route_pickup, actor=driver_user)
        count = await session.scalar(
            select(func.count())
            .select_from(DriverLocationSnapshot)
            .where(DriverLocationSnapshot.job_id == job.id)
        )
    assert count == 0


async def test_event_hook_receives_job_old_and_new(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    events: list[tuple[JobStatus, JobStatus]] = []

    async def hook(job: Job, old: JobStatus, new: JobStatus) -> None:
        events.append((old, new))

    job = await make_job(session_maker, customer_user, status=JobStatus.requested)
    async with session_maker() as session:
        job = await session.merge(job)
        await transition(session, job, JobStatus.matching, actor=customer_user, event_hook=hook)
    assert events == [(JobStatus.requested, JobStatus.matching)]


@pytest.mark.parametrize("status", [JobStatus.requested, JobStatus.matching])
async def test_customer_cancel_before_assign_is_free(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    status: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=status)
    async with session_maker() as session:
        job = await session.merge(job)
        await cancel_job(session, fake_redis, job, actor=customer_user)
    assert job.status is JobStatus.cancelled
    assert job.cancel_reason == "customer"
    assert job.cancelled_at is not None


async def test_customer_cancel_assigned_within_grace(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.assigned,
        driver=driver_user,
        assigned_at=datetime.now(UTC),
    )
    async with session_maker() as session:
        job = await session.merge(job)
        await cancel_job(session, fake_redis, job, actor=customer_user)
    assert job.status is JobStatus.cancelled
    assert job.cancel_reason == "customer"


async def test_customer_cancel_assigned_after_grace_records_reason(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.assigned,
        driver=driver_user,
        assigned_at=datetime.now(UTC) - timedelta(seconds=300),
    )
    async with session_maker() as session:
        job = await session.merge(job)
        await cancel_job(session, fake_redis, job, actor=customer_user)
    assert job.status is JobStatus.cancelled
    assert job.cancel_reason == "customer_after_assign"


async def test_cancel_grace_period_is_config_driven(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    """A wide configured grace keeps a 5-minute-old assignment a free cancel."""
    async with session_maker() as session:
        await set_config(session, fake_redis, "dispatch", {"cancel_grace_seconds": 600})
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.assigned,
        driver=driver_user,
        assigned_at=datetime.now(UTC) - timedelta(seconds=300),
    )
    async with session_maker() as session:
        job = await session.merge(job)
        await cancel_job(session, fake_redis, job, actor=customer_user)
    assert job.cancel_reason == "customer"


@pytest.mark.parametrize(
    "status",
    [JobStatus.loading, JobStatus.in_transit, JobStatus.delivered, JobStatus.completed],
)
async def test_customer_cancel_rejected_late(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
    status: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=status, driver=driver_user)
    async with session_maker() as session:
        job = await session.merge(job)
        with pytest.raises(JobTransitionError):
            await cancel_job(session, fake_redis, job, actor=customer_user)
    assert job.status is status


@pytest.mark.parametrize(
    "status",
    [JobStatus.assigned, JobStatus.en_route_pickup, JobStatus.arrived_pickup],
)
async def test_driver_cancel_returns_job_to_matching(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
    status: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=status, driver=driver_user)
    async with session_maker() as session:
        job = await session.merge(job)
        await cancel_job(session, fake_redis, job, actor=driver_user)
    assert job.status is JobStatus.matching
    assert job.driver_id is None  # released for re-dispatch (DSP-2)


async def test_driver_cancel_after_loading_rejected(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.loading, driver=driver_user)
    async with session_maker() as session:
        job = await session.merge(job)
        with pytest.raises(JobTransitionError):
            await cancel_job(session, fake_redis, job, actor=driver_user)
    assert job.status is JobStatus.loading


async def test_stranger_cannot_cancel(
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
) -> None:
    stranger = await _create_user(session_maker, "stranger-uid", customer_user.role)
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    async with session_maker() as session:
        job = await session.merge(job)
        with pytest.raises(JobAccessError):
            await cancel_job(session, fake_redis, job, actor=stranger)
    assert job.status is JobStatus.matching
