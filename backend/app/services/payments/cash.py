"""Cash gateway (LED-3): the MVP's only PaymentGateway. There is no external
service — the driver physically collects the fare — so `create_intent`
settles the payment synchronously; there is no pending/processing phase to
poll, no refund flow yet, and no webhooks."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.job import Job, PaymentMethod
from app.models.ledger import Payment, PaymentStatus
from app.models.ledger import PaymentProvider as PaymentProviderEnum
from app.services.payments.base import WebhookEvent, payment_reference


class CashGateway:
    """Implements `PaymentGateway` for cash-on-delivery."""

    async def create_intent(self, session: AsyncSession, job: Job) -> tuple[Payment, bool]:
        reference = payment_reference(job)
        existing = await session.scalar(select(Payment).where(Payment.reference == reference))
        if existing is not None:
            return existing, False

        payment = Payment(
            job_id=job.id,
            provider=PaymentProviderEnum.cash,
            reference=reference,
            amount=int(job.final_price),
            method=PaymentMethod.cash,
            status=PaymentStatus.approved,
            settled_at=datetime.now(UTC),
        )
        session.add(payment)
        await session.flush()  # payment.id available to the caller immediately
        return payment, True

    async def get_status(self, session: AsyncSession, payment: Payment) -> PaymentStatus:
        del session  # cash never changes state after creation — nothing to refresh
        return payment.status

    async def refund(
        self, session: AsyncSession, payment: Payment, *, reason: str | None = None
    ) -> Payment:
        del reason  # no ledger-side reversal yet — recorded once refunds are designed
        payment.status = PaymentStatus.refunded
        session.add(payment)
        return payment

    def parse_webhook(self, payload: dict) -> WebhookEvent:
        del payload
        raise NotImplementedError("cash has no webhooks — nothing calls this yet")
