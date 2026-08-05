"""LED-3: PaymentGateway protocol + CashGateway, and confirm_delivery's use of it."""

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import Job, JobStatus, PaymentMethod
from app.models.ledger import DriverLedgerEntry, Payment, PaymentStatus
from app.models.ledger import PaymentProvider as PaymentProviderEnum
from app.models.user import User
from app.services.jobs import confirm_delivery
from app.services.payments.base import payment_reference
from app.services.payments.cash import CashGateway
from tests.conftest import make_job

PERCENT_SNAPSHOT = {
    "pricing": {"car": {"base": 60000, "per_km": 5000, "min": 80000}},
    "commission": {"mode": "percent", "rate": {"moto": 0.15, "car": 0.15, "suv": 0.15}},
}


async def test_create_intent_is_idempotent(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        final_price=110000,
    )
    gateway = CashGateway()
    async with session_maker() as session:
        job = await session.merge(job)
        first, created_first = await gateway.create_intent(session, job)
        await session.commit()
        second, created_second = await gateway.create_intent(session, job)

    assert created_first is True
    assert created_second is False
    assert first.id == second.id
    assert first.reference == payment_reference(job)
    assert first.status is PaymentStatus.approved
    assert first.provider is PaymentProviderEnum.cash
    assert first.method is PaymentMethod.cash
    assert first.amount == 110000


async def test_get_status_returns_current_status(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        final_price=110000,
    )
    gateway = CashGateway()
    async with session_maker() as session:
        job = await session.merge(job)
        payment, _ = await gateway.create_intent(session, job)
        status = await gateway.get_status(session, payment)
    assert status is PaymentStatus.approved


async def test_refund_marks_payment_refunded(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        final_price=110000,
    )
    gateway = CashGateway()
    async with session_maker() as session:
        job = await session.merge(job)
        payment, _ = await gateway.create_intent(session, job)
        await session.commit()
        refunded = await gateway.refund(session, payment, reason="customer dispute")
        await session.commit()
    assert refunded.status is PaymentStatus.refunded


def test_parse_webhook_not_implemented_for_cash() -> None:
    gateway = CashGateway()
    with pytest.raises(NotImplementedError):
        gateway.parse_webhook({"anything": "goes"})


async def test_confirm_delivery_uses_injected_gateway(
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    """The API layer never has to change to swap gateways — confirm_delivery
    accepts one, defaulting to cash via get_payment_gateway()."""
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    calls: list[Job] = []

    class RecordingGateway(CashGateway):
        async def create_intent(self, session: AsyncSession, job: Job) -> tuple[Payment, bool]:
            calls.append(job)
            return await super().create_intent(session, job)

    async with session_maker() as session:
        job = await session.merge(job)
        await confirm_delivery(
            session, job, actor=customer_user, payment_gateway=RecordingGateway()
        )

    assert len(calls) == 1
    async with session_maker() as session:
        payment = await session.scalar(select(Payment).where(Payment.job_id == job.id))
        entry = await session.scalar(
            select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == job.id)
        )
    assert payment is not None
    assert entry is not None
