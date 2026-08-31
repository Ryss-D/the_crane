"""Wompi gateway (PAY-2): cards/PSE/Nequi via Wompi's real Checkout API
(https://docs.wompi.co), implementing the same `PaymentGateway` protocol
`CashGateway` does. Gated behind `settings.wompi_private_key` exactly like
`GoogleDirectionsClient` is gated behind `google_maps_api_key` (app/services/
pricing.py) -- unset means every call raises `WompiNotConfiguredError`
rather than silently pretending to succeed.

No real Wompi sandbox account exists yet as of this pass (2026-08-30) -- this
is real, tested code (signature verification and the request-building logic
are unit-tested against fixtures matching Wompi's documented shapes) that has
never made a live call. See the PAY-1..5 doc note in
docs/tasks/12-payments-wompi.md.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.job import Job, PaymentMethod
from app.models.ledger import Payment, PaymentStatus
from app.models.ledger import PaymentProvider as PaymentProviderEnum
from app.models.user import User
from app.services.payments.base import WebhookEvent, payment_reference

SANDBOX_BASE_URL = "https://sandbox.wompi.co/v1"
PRODUCTION_BASE_URL = "https://production.wompi.co/v1"

# Wompi's own transaction-status vocabulary -> this app's PaymentStatus.
_WOMPI_STATUS_MAP = {
    "PENDING": PaymentStatus.pending,
    "APPROVED": PaymentStatus.approved,
    "DECLINED": PaymentStatus.declined,
    "VOIDED": PaymentStatus.declined,
    "ERROR": PaymentStatus.declined,
}

# A payment's status can only move forward through this ordering -- an event
# reporting a status at or behind the current one is stale/out-of-order and
# must be a no-op (PAY-1's AC). Terminal statuses (everything past
# `processing`) never move again once reached.
_STATUS_RANK = {
    PaymentStatus.pending: 0,
    PaymentStatus.processing: 1,
    PaymentStatus.approved: 2,
    PaymentStatus.declined: 2,
    PaymentStatus.expired: 2,
    PaymentStatus.refunded: 3,
}


class WompiNotConfiguredError(Exception):
    """No `WOMPI_PRIVATE_KEY` (or events/public key, depending on the call)
    configured -- the API layer maps this to a 503, same as
    `GoogleDirectionsClient`'s unconfigured-key path."""


class WompiApiError(Exception):
    """Wompi's API returned a non-success response."""


def is_stale_status(current: PaymentStatus, incoming: PaymentStatus) -> bool:
    """True if `incoming` would not advance `current` per `_STATUS_RANK` --
    PAY-1's "out-of-order-tolerant" requirement: applying a stale/duplicate
    event must be a safe no-op, not an error."""
    return _STATUS_RANK[incoming] <= _STATUS_RANK[current]


def verify_event_signature(payload: dict[str, Any], events_key: str) -> bool:
    """Wompi's events-signature check (https://docs.wompi.co -> "Eventos" ->
    "Verificación de eventos"): the payload carries `signature.properties`
    (an ordered list of dot-paths into `data`), `signature.checksum`, and a
    top-level `timestamp`. The expected checksum is
    `sha256(concat(values-at-those-paths) + str(timestamp) + events_key)`,
    hex-encoded. Returns False (never raises) on any malformed/missing field
    -- an unverifiable event is treated the same as a forged one.
    """
    try:
        signature = payload["signature"]
        properties: list[str] = signature["properties"]
        expected_checksum: str = signature["checksum"]
        timestamp = payload["timestamp"]
        data = payload["data"]
    except (KeyError, TypeError):
        return False

    concatenated = ""
    for path in properties:
        value: Any = data
        for part in path.split("."):
            if not isinstance(value, dict) or part not in value:
                return False
            value = value[part]
        concatenated += str(value)
    concatenated += str(timestamp)
    concatenated += events_key

    computed = hashlib.sha256(concatenated.encode("utf-8")).hexdigest()
    # Constant-time compare -- this guards a webhook signature, so a
    # timing side-channel on the checksum comparison is worth closing even
    # though `==` would have been functionally correct.
    return hmac.compare_digest(computed.lower(), str(expected_checksum).lower())


@dataclass(frozen=True)
class WompiCheckout:
    """What `WompiGateway.create_intent` hands back beyond the bare
    `Payment` row -- the piece of the real Wompi response a client needs to
    actually complete the payment."""

    payment: Payment
    created: bool
    wompi_transaction_id: str | None
    # Present for an async (PSE) redirect flow; None for a card transaction,
    # which instead needs a client-side 3DS redirect this backend never sees
    # (Wompi's card flow tokenizes on the client with the *public* key --
    # this backend only ever creates the transaction after that, per Wompi's
    # own documented flow; there is deliberately no server-side card number
    # handling here).
    async_payment_url: str | None


class WompiGateway:
    """Implements `PaymentGateway`. Every method needs `settings.wompi_private_key`
    configured; `create_intent`/`get_status` additionally need network access to
    Wompi's API. `parse_webhook` needs `settings.wompi_events_key` instead (no
    private-key call involved in verifying a webhook)."""

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()

    @property
    def _base_url(self) -> str:
        return PRODUCTION_BASE_URL if self._settings.wompi_env == "prod" else SANDBOX_BASE_URL

    def _require_private_key(self) -> str:
        if not self._settings.wompi_private_key:
            raise WompiNotConfiguredError("WOMPI_PRIVATE_KEY is not configured")
        return self._settings.wompi_private_key

    async def _acceptance_token(self, client: httpx.AsyncClient) -> str:
        """Wompi requires every transaction to carry the merchant's current
        terms-of-service acceptance token, fetched fresh from the public
        merchant-info endpoint (it rotates and is cheap to re-fetch -- Wompi's
        own docs recommend not caching it)."""
        public_key = self._settings.wompi_public_key
        if not public_key:
            raise WompiNotConfiguredError("WOMPI_PUBLIC_KEY is not configured")
        response = await client.get(f"{self._base_url}/merchants/{public_key}")
        if response.status_code != 200:
            raise WompiApiError(f"Wompi merchant lookup failed: {response.status_code}")
        return response.json()["data"]["presigned_acceptance"]["acceptance_token"]

    async def _create_transaction(
        self,
        *,
        reference: str,
        amount_in_cents: int,
        customer_email: str,
        payment_method: dict[str, Any],
    ) -> dict[str, Any]:
        private_key = self._require_private_key()
        async with httpx.AsyncClient(timeout=15.0) as client:
            acceptance_token = await self._acceptance_token(client)
            response = await client.post(
                f"{self._base_url}/transactions",
                headers={"Authorization": f"Bearer {private_key}"},
                json={
                    "acceptance_token": acceptance_token,
                    "amount_in_cents": amount_in_cents,
                    "currency": "COP",
                    "customer_email": customer_email,
                    "reference": reference,
                    "payment_method": payment_method,
                },
            )
        if response.status_code not in (200, 201):
            raise WompiApiError(f"Wompi transaction creation failed: {response.status_code}")
        return response.json()["data"]

    async def create_checkout(
        self,
        session: AsyncSession,
        *,
        reference: str,
        amount: int,
        customer_email: str,
        payment_method_type: PaymentMethod,
        job_id: Any = None,
        payment_method_extra: dict[str, Any] | None = None,
    ) -> WompiCheckout:
        """Shared by PAY-2 (job digital fares) and PAY-3 (driver settlements)
        -- both are "create a Wompi transaction for `amount` COP under
        `reference`", differing only in what `reference` encodes and whether
        a `job_id` is attached to the resulting `Payment` row.

        Idempotent the same way `CashGateway.create_intent` is: an existing
        `Payment` for `reference` is returned as-is (`created=False`) rather
        than creating a second Wompi transaction.
        """
        existing = await session.scalar(select(Payment).where(Payment.reference == reference))
        if existing is not None:
            return WompiCheckout(
                payment=existing, created=False, wompi_transaction_id=existing.provider_ref,
                async_payment_url=None,
            )

        payment_method: dict[str, Any] = {"type": payment_method_type.value.upper()}
        payment_method.update(payment_method_extra or {})
        wompi_amount_cents = amount * 100  # this app's COP amounts have no sub-unit; Wompi's do
        transaction = await self._create_transaction(
            reference=reference,
            amount_in_cents=wompi_amount_cents,
            customer_email=customer_email,
            payment_method=payment_method,
        )
        wompi_status = _WOMPI_STATUS_MAP.get(transaction.get("status", ""), PaymentStatus.pending)
        payment = Payment(
            job_id=job_id,
            provider=PaymentProviderEnum.wompi,
            provider_ref=transaction["id"],
            reference=reference,
            amount=amount,
            method=payment_method_type,
            status=wompi_status,
        )
        session.add(payment)
        await session.flush()
        return WompiCheckout(
            payment=payment,
            created=True,
            wompi_transaction_id=transaction["id"],
            async_payment_url=transaction.get("payment_method", {}).get("extra", {}).get(
                "async_payment_url"
            ),
        )

    # -- PaymentGateway protocol -------------------------------------------------

    async def create_intent(self, session: AsyncSession, job: Job) -> tuple[Payment, bool]:
        """PaymentGateway.create_intent for a job's digital fare (PAY-4).
        `Job` has no ORM relationship to its customer `User` row (only
        `customer_id`), so this fetches it directly rather than assuming
        one -- same pattern `_job_read`'s driver/customer summaries use in
        `app/api/jobs.py`."""
        customer = await session.get(User, job.customer_id)
        customer_email = (customer.email if customer else None) or f"{job.customer_id}@thecrane.app"
        checkout = await self.create_checkout(
            session,
            reference=payment_reference(job),
            amount=int(job.final_price),
            customer_email=customer_email,
            payment_method_type=job.payment_method,
            job_id=job.id,
        )
        # PAY-4: `PaymentGateway.create_intent`'s protocol shape (shared with
        # `CashGateway`, which has no checkout URL to give) is `tuple[Payment,
        # bool]` -- no room for `checkout.async_payment_url`. Stashing it as a
        # transient (non-persisted, non-mapped) attribute on `job` is the
        # least invasive way to get it to `confirm_delivery_endpoint`'s
        # response without changing that shared protocol or adding a second
        # return path just for one gateway. `job` is the same in-memory
        # instance `_job_read` builds the response from, in the same request.
        job.pending_payment_url = checkout.async_payment_url
        return checkout.payment, checkout.created

    async def get_status(self, session: AsyncSession, payment: Payment) -> PaymentStatus:
        del session
        private_key = self._require_private_key()
        if payment.provider_ref is None:
            return payment.status
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{self._base_url}/transactions/{payment.provider_ref}",
                headers={"Authorization": f"Bearer {private_key}"},
            )
        if response.status_code != 200:
            raise WompiApiError(f"Wompi status lookup failed: {response.status_code}")
        data = response.json()["data"]
        return _WOMPI_STATUS_MAP.get(data.get("status", ""), payment.status)

    async def refund(
        self, session: AsyncSession, payment: Payment, *, reason: str | None = None
    ) -> Payment:
        del reason
        private_key = self._require_private_key()
        if payment.provider_ref is None:
            raise WompiApiError("Cannot refund a payment with no Wompi transaction id")
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{self._base_url}/transactions/{payment.provider_ref}/void",
                headers={"Authorization": f"Bearer {private_key}"},
            )
        if response.status_code not in (200, 201):
            raise WompiApiError(f"Wompi void/refund failed: {response.status_code}")
        payment.status = PaymentStatus.refunded
        payment.settled_at = datetime.now(UTC)
        session.add(payment)
        return payment

    def parse_webhook(self, payload: dict[str, Any]) -> WebhookEvent:
        events_key = self._settings.wompi_events_key
        if not events_key:
            raise WompiNotConfiguredError("WOMPI_EVENTS_KEY is not configured")
        if not verify_event_signature(payload, events_key):
            raise WompiApiError("Invalid Wompi event signature")
        transaction = payload["data"]["transaction"]
        status_value = _WOMPI_STATUS_MAP.get(transaction.get("status", ""), PaymentStatus.pending)
        return WebhookEvent(
            reference=transaction["reference"], status=status_value, raw=payload
        )
