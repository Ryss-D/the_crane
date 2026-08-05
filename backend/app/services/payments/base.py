"""PaymentGateway protocol (LED-3): the abstraction Wompi (PAY-2) implements
later without touching app/api or app/services/jobs.py.

Named `PaymentGateway`, not `PaymentProvider`, to avoid colliding with
`app.models.ledger.PaymentProvider` — that's the DB enum recording *which*
gateway a payment used (cash|wompi|mercadopago); this is the Python interface
each gateway implements. `CashGateway` (cash.py) is the first implementation
— it never talks to an external service, so `create_intent` settles
synchronously and `refund`/`parse_webhook` exist only to satisfy the shape
until PAY-2 needs them for real.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.job import Job
from app.models.ledger import Payment, PaymentStatus


@dataclass(frozen=True)
class WebhookEvent:
    """Normalized shape a provider's `parse_webhook` returns — enough for the
    caller to look up the Payment by reference and apply a status transition,
    regardless of the gateway's own payload shape."""

    reference: str
    status: PaymentStatus
    raw: dict


class PaymentGateway(Protocol):
    """One gateway's payment lifecycle. `CashGateway` today; Wompi (PAY-2)
    implements the same shape against a real API + webhook signature check."""

    async def create_intent(self, session: AsyncSession, job: Job) -> tuple[Payment, bool]:
        """Create (or, if `job` already has one, fetch) this job's payment.

        Returns `(payment, created)` — `created` is False when a payment for
        this job already existed (idempotent retry), so callers know whether
        to run first-time-only side effects (e.g. the ledger entry).
        """
        ...

    async def get_status(self, session: AsyncSession, payment: Payment) -> PaymentStatus:
        """Current status, refreshed from the gateway if this provider polls."""
        ...

    async def refund(
        self, session: AsyncSession, payment: Payment, *, reason: str | None = None
    ) -> Payment:
        """Refund a settled payment."""
        ...

    def parse_webhook(self, payload: dict) -> WebhookEvent:
        """Turn a gateway webhook payload into a WebhookEvent. Raises
        NotImplementedError for providers (like cash) with no webhooks."""
        ...


def payment_reference(job: Job) -> str:
    """Unique payment reference for a job — the idempotency key shared by
    every gateway (one job, one payment, no matter how many times a caller
    retries create_intent)."""
    return f"job_{job.id}"
