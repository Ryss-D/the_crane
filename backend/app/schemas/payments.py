"""Schemas for the Wompi endpoints (PAY-1/3, app/api/payments.py)."""

from pydantic import BaseModel

from app.models.job import PaymentMethod


class DriverSettleRequest(BaseModel):
    """POST /v1/drivers/me/settle body — same `amount` shape as the admin
    settlement request (`app/schemas/admin.py`'s `LedgerSettleRequest`), plain
    COP, no sub-unit."""

    amount: int
    payment_method: PaymentMethod = PaymentMethod.nequi


class DriverSettleResponse(BaseModel):
    """What the driver app needs to complete the Wompi checkout: the payment
    reference (for polling `GET /v1/drivers/me/balance` afterward) and, for
    an async (PSE) method, the URL to redirect the driver to. Null for a
    method with no redirect step at this stage of the flow (e.g. Nequi,
    which instead pushes a push-notification/OTP prompt in the driver's own
    Nequi app -- nothing for this backend to hand back)."""

    payment_reference: str
    async_payment_url: str | None = None


class WompiWebhookAck(BaseModel):
    """POST /v1/webhooks/wompi's own response — Wompi only checks for a 2xx,
    but a real body makes manual/sandbox debugging saner than a bare 204."""

    received: bool
    applied: bool
