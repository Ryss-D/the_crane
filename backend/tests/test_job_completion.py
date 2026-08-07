"""JOB-6 + LED-1 tests: driver status endpoint, confirm-delivery, completion accrual."""

from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import DriverLocationSnapshot, Job, JobStatus
from app.models.ledger import (
    DriverLedgerEntry,
    LedgerEntryType,
    Payment,
    PaymentProvider,
    PaymentStatus,
)
from app.models.user import User, UserRole
from app.services.config import set_config
from tests.conftest import FakeRedis, _create_user, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}
AUTH_DRIVER = {"Authorization": "Bearer driver-token"}

PERCENT_SNAPSHOT = {
    "pricing": {"car": {"base": 60000, "per_km": 5000, "min": 80000}},
    "commission": {"mode": "percent", "rate": {"moto": 0.15, "car": 0.15, "suv": 0.15}},
}
FLAT_SNAPSHOT = {
    "pricing": {"car": {"base": 60000, "per_km": 5000, "min": 80000}},
    "commission": {"mode": "flat", "amount": {"moto": 8000, "car": 12000, "suv": 15000}},
}


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]], customer_user: User, driver_user: User
) -> dict[str, dict[str, Any]]:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["driver-token"] = {"uid": driver_user.firebase_uid}
    return verified_tokens


async def _accrual_rows(
    session_maker: async_sessionmaker[AsyncSession], job_id: Any
) -> tuple[list[Payment], list[DriverLedgerEntry]]:
    async with session_maker() as session:
        payments = (await session.scalars(select(Payment).where(Payment.job_id == job_id))).all()
        entries = (
            await session.scalars(
                select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == job_id)
            )
        ).all()
        return list(payments), list(entries)


async def test_driver_advances_full_happy_path_then_customer_confirms(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.assigned,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    for step in ("en_route_pickup", "arrived_pickup", "loading", "in_transit", "delivered"):
        response = await client.post(
            f"/v1/jobs/{job.id}/status", headers=AUTH_DRIVER, json={"status": step}
        )
        assert response.status_code == 200, (step, response.json())
        assert response.json()["status"] == step

    confirm = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert confirm.status_code == 200
    body = confirm.json()
    assert body["status"] == "completed"
    assert body["final_price"] == 110000
    assert body["completed_at"] is not None


async def test_status_update_rejects_non_assigned_driver(
    client: AsyncClient,
    tokens: dict,
    verified_tokens: dict[str, dict[str, Any]],
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    intruder = await _create_user(session_maker, "intruder-uid", UserRole.driver)
    verified_tokens["intruder-token"] = {"uid": intruder.firebase_uid}
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    response = await client.post(
        f"/v1/jobs/{job.id}/status",
        headers={"Authorization": "Bearer intruder-token"},
        json={"status": "en_route_pickup"},
    )
    assert response.status_code == 403


async def test_status_update_out_of_order_409(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    response = await client.post(
        f"/v1/jobs/{job.id}/status", headers=AUTH_DRIVER, json={"status": "in_transit"}
    )
    assert response.status_code == 409


async def test_driver_cannot_set_completed_or_dispatch_statuses(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.delivered, driver=driver_user
    )
    completed = await client.post(
        f"/v1/jobs/{job.id}/status", headers=AUTH_DRIVER, json={"status": "completed"}
    )
    assert completed.status_code == 403  # customer-only via confirm-delivery
    assigned = await client.post(
        f"/v1/jobs/{job.id}/status", headers=AUTH_DRIVER, json={"status": "assigned"}
    )
    assert assigned.status_code == 409


async def test_status_update_records_location_snapshot(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.assigned, driver=driver_user
    )
    response = await client.post(
        f"/v1/jobs/{job.id}/status",
        headers=AUTH_DRIVER,
        json={"status": "en_route_pickup", "lat": 6.21, "lng": -75.59},
    )
    assert response.status_code == 200
    async with session_maker() as session:
        count = await session.scalar(
            select(func.count())
            .select_from(DriverLocationSnapshot)
            .where(DriverLocationSnapshot.job_id == job.id)
        )
    assert count == 1


async def test_confirm_delivery_writes_percent_accrual(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    response = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert response.status_code == 200

    payments, entries = await _accrual_rows(session_maker, job.id)
    assert len(payments) == 1
    payment = payments[0]
    assert payment.provider is PaymentProvider.cash
    assert payment.status is PaymentStatus.approved
    assert payment.reference == f"job_{job.id}"
    assert int(payment.amount) == 110000
    assert payment.settled_at is not None

    assert len(entries) == 1
    entry = entries[0]
    assert entry.driver_id == driver_user.id
    assert entry.entry_type is LedgerEntryType.earning
    assert int(entry.gross) == 110000
    assert int(entry.commission) == round(110000 * 0.15)  # 16500
    assert int(entry.net) == 110000 - 16500


async def test_confirm_delivery_writes_flat_accrual(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=FLAT_SNAPSHOT,
    )
    response = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert response.status_code == 200

    _, entries = await _accrual_rows(session_maker, job.id)
    assert int(entries[0].commission) == 12000  # flat amount for `car`
    assert int(entries[0].net) == 110000 - 12000


async def test_commission_uses_job_snapshot_not_current_config(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    # Config changes AFTER the job was created must not affect its commission.
    async with session_maker() as session:
        await set_config(
            session, fake_redis, "commission", {"mode": "percent", "rate": {"car": 0.30}}
        )
    response = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert response.status_code == 200
    _, entries = await _accrual_rows(session_maker, job.id)
    assert int(entries[0].commission) == round(110000 * 0.15)


async def test_confirm_delivery_is_idempotent_under_double_call(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    first = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    second = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert first.status_code == 200
    assert second.status_code == 200  # retry-safe
    assert second.json()["status"] == "completed"

    payments, entries = await _accrual_rows(session_maker, job.id)
    assert len(payments) == 1  # exactly once
    assert len(entries) == 1


@pytest.mark.parametrize(
    "status",
    [JobStatus.assigned, JobStatus.loading, JobStatus.in_transit, JobStatus.cancelled],
)
async def test_confirm_delivery_only_from_delivered(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    status: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=status, driver=driver_user)
    response = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert response.status_code == 409
    payments, entries = await _accrual_rows(session_maker, job.id)
    assert payments == [] and entries == []


async def test_driver_commission_null_before_completion(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    """DRV-4: driver_commission stays null until the job is actually completed --
    there's no ledger earning row to read it from before then."""
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    response = await client.get(f"/v1/jobs/{job.id}", headers=AUTH_DRIVER)
    assert response.status_code == 200
    assert response.json()["driver_commission"] is None


async def test_driver_commission_matches_ledger_entry_after_completion(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    """DRV-4: driver_commission is the real LED-1 ledger commission (config
    snapshot's 15% of the 110000 fare = 16500), not a client-side flat guess --
    and a later GET reads the same persisted ledger row, not a re-derived value."""
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    confirm = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_CUSTOMER)
    assert confirm.status_code == 200
    assert confirm.json()["driver_commission"] == round(110000 * 0.15)  # 16500

    _, entries = await _accrual_rows(session_maker, job.id)
    assert entries[0].entry_type is LedgerEntryType.earning
    assert confirm.json()["driver_commission"] == int(entries[0].commission)

    get_resp = await client.get(f"/v1/jobs/{job.id}", headers=AUTH_DRIVER)
    assert get_resp.json()["driver_commission"] == int(entries[0].commission)


async def test_confirm_delivery_only_by_the_jobs_customer(
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
        session_maker, customer_user, status=JobStatus.delivered, driver=driver_user
    )
    as_driver = await client.post(f"/v1/jobs/{job.id}/confirm-delivery", headers=AUTH_DRIVER)
    as_other = await client.post(
        f"/v1/jobs/{job.id}/confirm-delivery", headers={"Authorization": "Bearer other-token"}
    )
    assert as_driver.status_code == 403
    assert as_other.status_code == 403
    async with session_maker() as session:
        refreshed = await session.get(Job, job.id)
        assert refreshed is not None and refreshed.status is JobStatus.delivered
