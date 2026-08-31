"""PAY-5: reconciliation job tests -- seeded mismatch is detected and
reported; a clean set of payments reports nothing; no key configured is a
graceful no-op."""

from typing import Any

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import PaymentMethod
from app.models.ledger import Payment, PaymentStatus
from app.models.user import User
from scripts.reconcile_wompi import find_mismatches
from tests.conftest import make_job
from tests.test_payments_wompi import (
    _FakeWompiResponse,
)


async def test_find_mismatches_reports_a_seeded_mismatch(
    monkeypatch: pytest.MonkeyPatch,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    wompi_configured: Any,
) -> None:
    job = await make_job(session_maker, customer_user, driver=driver_user, final_price=100000)
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=job.id,
                provider="wompi",
                provider_ref="wompi-recon-1",
                reference=f"job_{job.id}",
                amount=100000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.pending,  # local: still pending
            )
        )
        await session.commit()

    monkeypatch.setattr("scripts.reconcile_wompi.get_sessionmaker", lambda: session_maker)
    # get_status uses .get(), not .post() -- patch the GET response to report
    # APPROVED (Wompi's real view) while local status stays `pending`.
    monkeypatch.setattr(
        "app.services.payments.wompi.httpx.AsyncClient",
        lambda **_: _FakeGetOnlyClient(_FakeWompiResponse(200, {"data": {"status": "APPROVED"}})),
    )

    mismatches = await find_mismatches(hours=24)

    assert len(mismatches) == 1
    assert mismatches[0].local_status is PaymentStatus.pending
    assert mismatches[0].wompi_status is PaymentStatus.approved


class _FakeGetOnlyClient:
    def __init__(self, response: _FakeWompiResponse) -> None:
        self._response = response

    async def __aenter__(self) -> "_FakeGetOnlyClient":
        return self

    async def __aexit__(self, *exc: Any) -> None:
        return None

    async def get(self, *args: Any, **kwargs: Any) -> _FakeWompiResponse:
        return self._response


async def test_find_mismatches_reports_nothing_when_statuses_agree(
    monkeypatch: pytest.MonkeyPatch,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    wompi_configured: Any,
) -> None:
    job = await make_job(session_maker, customer_user, driver=driver_user, final_price=100000)
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=job.id,
                provider="wompi",
                provider_ref="wompi-recon-2",
                reference=f"job_{job.id}",
                amount=100000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.approved,
            )
        )
        await session.commit()

    monkeypatch.setattr("scripts.reconcile_wompi.get_sessionmaker", lambda: session_maker)
    monkeypatch.setattr(
        "app.services.payments.wompi.httpx.AsyncClient",
        lambda **_: _FakeGetOnlyClient(_FakeWompiResponse(200, {"data": {"status": "APPROVED"}})),
    )

    mismatches = await find_mismatches(hours=24)

    assert mismatches == []


async def test_find_mismatches_without_key_configured_returns_empty(
    monkeypatch: pytest.MonkeyPatch,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    # No `wompi_configured` fixture here -- WOMPI_PRIVATE_KEY stays unset.
    job = await make_job(session_maker, customer_user, driver=driver_user, final_price=100000)
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=job.id,
                provider="wompi",
                provider_ref="wompi-recon-3",
                reference=f"job_{job.id}",
                amount=100000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.pending,
            )
        )
        await session.commit()

    monkeypatch.setattr("scripts.reconcile_wompi.get_sessionmaker", lambda: session_maker)
    mismatches = await find_mismatches(hours=24)
    assert mismatches == []
