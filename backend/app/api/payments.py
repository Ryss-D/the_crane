"""Wompi webhook (PAY-1). Unauthenticated by nature (Wompi calls this, not a
signed-in user) — `WompiGateway.parse_webhook`'s signature check is what
proves a request is genuinely from Wompi, not a bearer token.
"""

import uuid
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models.job import Job
from app.models.ledger import (
    DriverLedgerEntry,
    LedgerEntryType,
    Payment,
    PaymentEvent,
    PaymentStatus,
)
from app.schemas.payments import WompiWebhookAck
from app.services.jobs import apply_ledger_for_settled_payment
from app.services.payments.wompi import (
    WompiApiError,
    WompiGateway,
    WompiNotConfiguredError,
    is_stale_status,
)

router = APIRouter(tags=["payments"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


def _driver_id_from_settlement_reference(reference: str) -> uuid.UUID:
    """`settlement_<driver-uuid>_<random-hex>` -> the driver uuid (see
    `app/api/drivers.py`'s `settle_my_balance`, which mints references in
    exactly this shape). UUIDs use hyphens, never underscores, so splitting
    on "_" is unambiguous."""
    return uuid.UUID(reference.split("_")[1])


@router.post("/webhooks/wompi", response_model=WompiWebhookAck)
async def wompi_webhook(
    session: SessionDep, payload: Annotated[dict[str, Any], Body()]
) -> WompiWebhookAck:
    """PAY-1: signature-verified, idempotent, out-of-order-tolerant.

    Always acks 2xx once the signature itself checks out (even for an
    unknown reference, or a stale/duplicate event) — the only thing that
    should make Wompi keep retrying is *not being able to verify the
    request at all*, which is exactly what the 401 branch below is for.
    """
    gateway = WompiGateway()
    try:
        event = gateway.parse_webhook(payload)
    except WompiNotConfiguredError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    except WompiApiError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    payment = await session.scalar(select(Payment).where(Payment.reference == event.reference))
    if payment is None:
        return WompiWebhookAck(received=True, applied=False)

    # PAY-1 idempotency: `data.transaction.{id,status}` is this event's
    # identity -- the *same* transaction reaching the *same* status twice
    # (a Wompi retry, or a genuine duplicate delivery) must insert nothing
    # and change nothing a second time.
    transaction = payload["data"]["transaction"]
    dedup_key = f"{transaction.get('id')}:{transaction.get('status')}"
    already_seen = await session.scalar(
        select(PaymentEvent).where(
            PaymentEvent.payment_id == payment.id, PaymentEvent.dedup_key == dedup_key
        )
    )
    if already_seen is not None:
        return WompiWebhookAck(received=True, applied=False)

    session.add(PaymentEvent(payment_id=payment.id, dedup_key=dedup_key, payload=payload))

    applied = False
    if not is_stale_status(payment.status, event.status):
        payment.status = event.status
        if event.status is PaymentStatus.approved:
            payment.settled_at = datetime.now(UTC)
            if payment.reference.startswith("job_") and payment.job_id is not None:
                job = await session.get(Job, payment.job_id)
                if job is not None:
                    await apply_ledger_for_settled_payment(session, job, payment)
            elif payment.reference.startswith("settlement_"):
                # PAY-3: same `payout` row shape the admin/fleet settlements
                # write (`app/api/admin.py`'s `settle_driver`/`settle_fleet`)
                # -- driver_owed_balance() picks it up on the next read, which
                # is what naturally "un-caps" the driver (there is no
                # separate capped flag to clear; DSP-1's gate just
                # re-evaluates `owed >= balance_cap` fresh every time).
                session.add(
                    DriverLedgerEntry(
                        driver_id=_driver_id_from_settlement_reference(payment.reference),
                        job_id=None,
                        gross=payment.amount,
                        commission=0,
                        net=payment.amount,
                        entry_type=LedgerEntryType.payout,
                        note="Wompi settlement",
                    )
                )
        session.add(payment)
        applied = True

    await session.commit()
    return WompiWebhookAck(received=True, applied=applied)
