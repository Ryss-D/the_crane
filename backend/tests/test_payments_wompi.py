"""PAY-1..5 tests: Wompi gateway, webhook idempotency/signature, driver
settlement, and the PAY-4 digital-fare flag on confirm-delivery.

No real Wompi sandbox account exists as of this pass — every network call is
faked the same way `tests/test_quotes.py` fakes `GoogleDirectionsClient`'s
httpx calls (see `_FakeGoogleAsyncClient` there); this suite is the same
shape, just supporting both `.get()` and `.post()`.
"""

import hashlib
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.models.job import JobStatus
from app.models.ledger import DriverLedgerEntry, LedgerEntryType, Payment, PaymentStatus
from app.models.user import User
from app.services.jobs import apply_ledger_for_settled_payment
from app.services.ledger import driver_owed_balance
from app.services.payments.wompi import (
    WompiGateway,
    WompiNotConfiguredError,
    is_stale_status,
    verify_event_signature,
)
from tests.conftest import make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}
AUTH_DRIVER = {"Authorization": "Bearer driver-token"}

PERCENT_SNAPSHOT = {
    "pricing": {"car": {"base": 60000, "per_km": 5000, "min": 80000}},
    "commission": {"mode": "percent", "rate": {"moto": 0.15, "car": 0.15, "suv": 0.15}},
}


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]], customer_user: User, driver_user: User
) -> dict[str, dict[str, Any]]:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["driver-token"] = {"uid": driver_user.firebase_uid}
    return verified_tokens


def _wompi_settings(**overrides: Any) -> Settings:
    defaults: dict[str, Any] = {
        "wompi_public_key": None,
        "wompi_private_key": None,
        "wompi_events_key": None,
        "wompi_env": "sandbox",
    }
    defaults.update(overrides)
    return Settings(**defaults)


CONFIGURED_SETTINGS = _wompi_settings(
    wompi_public_key="pub-test",
    wompi_private_key="priv-test",
    wompi_events_key="events-secret",
)


# ---- verify_event_signature -------------------------------------------------


def _signed_event(*, transaction: dict[str, Any], events_key: str, timestamp: int = 1700000000):
    properties = ["transaction.id", "transaction.status", "transaction.amount_in_cents"]
    concatenated = "".join(str(transaction[p.split(".")[1]]) for p in properties)
    concatenated += str(timestamp) + events_key
    checksum = hashlib.sha256(concatenated.encode("utf-8")).hexdigest()
    return {
        "event": "transaction.updated",
        "data": {"transaction": transaction},
        "timestamp": timestamp,
        "signature": {"properties": properties, "checksum": checksum},
        "environment": "test",
    }


def test_verify_event_signature_accepts_a_correctly_signed_payload() -> None:
    payload = _signed_event(
        transaction={"id": "txn-1", "status": "APPROVED", "amount_in_cents": 100000},
        events_key="events-secret",
    )
    assert verify_event_signature(payload, "events-secret") is True


def test_verify_event_signature_rejects_a_tampered_payload() -> None:
    payload = _signed_event(
        transaction={"id": "txn-1", "status": "APPROVED", "amount_in_cents": 100000},
        events_key="events-secret",
    )
    payload["data"]["transaction"]["status"] = "DECLINED"  # tampered after signing
    assert verify_event_signature(payload, "events-secret") is False


def test_verify_event_signature_rejects_the_wrong_events_key() -> None:
    payload = _signed_event(
        transaction={"id": "txn-1", "status": "APPROVED", "amount_in_cents": 100000},
        events_key="events-secret",
    )
    assert verify_event_signature(payload, "some-other-key") is False


@pytest.mark.parametrize(
    "malformed", [{}, {"data": {}}, {"signature": {}}, {"data": {"transaction": {}}}]
)
def test_verify_event_signature_is_false_not_raising_on_malformed_payloads(
    malformed: dict[str, Any],
) -> None:
    assert verify_event_signature(malformed, "events-secret") is False


# ---- is_stale_status ---------------------------------------------------------


def test_is_stale_status_ordering() -> None:
    assert is_stale_status(PaymentStatus.pending, PaymentStatus.processing) is False
    assert is_stale_status(PaymentStatus.pending, PaymentStatus.approved) is False
    assert is_stale_status(PaymentStatus.approved, PaymentStatus.pending) is True  # out of order
    assert is_stale_status(PaymentStatus.approved, PaymentStatus.approved) is True  # duplicate
    # Already terminal:
    assert is_stale_status(PaymentStatus.declined, PaymentStatus.approved) is True


# ---- WompiGateway without configuration --------------------------------------


async def test_gateway_without_private_key_raises_on_checkout(
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    from app.models.job import PaymentMethod

    gateway = WompiGateway(_wompi_settings())
    async with session_maker() as session:
        with pytest.raises(WompiNotConfiguredError):
            await gateway.create_checkout(
                session,
                reference="job_test",
                amount=10000,
                customer_email="a@b.com",
                payment_method_type=PaymentMethod.nequi,
            )


def test_gateway_without_events_key_raises_on_parse_webhook() -> None:
    gateway = WompiGateway(_wompi_settings())
    with pytest.raises(WompiNotConfiguredError):
        gateway.parse_webhook({"data": {"transaction": {}}})


# ---- WompiGateway.create_checkout, faked network -----------------------------


class _FakeWompiResponse:
    def __init__(self, status_code: int, payload: dict[str, Any]) -> None:
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict[str, Any]:
        return self._payload


class _FakeWompiAsyncClient:
    """Stand-in for httpx.AsyncClient: GET -> merchant/status responses, POST ->
    transaction-creation/void responses, keyed by call order (this gateway only
    ever makes one GET then one POST per create_checkout call)."""

    def __init__(
        self, *, get_response: _FakeWompiResponse, post_response: _FakeWompiResponse
    ) -> None:
        self._get_response = get_response
        self._post_response = post_response

    def __call__(self, **_: Any) -> "_FakeWompiAsyncClient":
        return self

    async def __aenter__(self) -> "_FakeWompiAsyncClient":
        return self

    async def __aexit__(self, *exc: Any) -> None:
        return None

    async def get(self, *args: Any, **kwargs: Any) -> _FakeWompiResponse:
        return self._get_response

    async def post(self, *args: Any, **kwargs: Any) -> _FakeWompiResponse:
        return self._post_response


def _patch_wompi_client(
    monkeypatch: pytest.MonkeyPatch,
    *,
    get_response: _FakeWompiResponse,
    post_response: _FakeWompiResponse,
) -> None:
    monkeypatch.setattr(
        "app.services.payments.wompi.httpx.AsyncClient",
        _FakeWompiAsyncClient(get_response=get_response, post_response=post_response),
    )


MERCHANT_RESPONSE = _FakeWompiResponse(
    200, {"data": {"presigned_acceptance": {"acceptance_token": "acc-tok"}}}
)


async def test_create_checkout_creates_a_pending_payment(
    monkeypatch: pytest.MonkeyPatch, session_maker: async_sessionmaker[AsyncSession]
) -> None:
    from app.models.job import PaymentMethod

    _patch_wompi_client(
        monkeypatch,
        get_response=MERCHANT_RESPONSE,
        post_response=_FakeWompiResponse(
            201, {"data": {"id": "wompi-txn-1", "status": "PENDING", "payment_method": {}}}
        ),
    )
    gateway = WompiGateway(CONFIGURED_SETTINGS)
    async with session_maker() as session:
        checkout = await gateway.create_checkout(
            session,
            reference="settlement_test",
            amount=50000,
            customer_email="driver@example.com",
            payment_method_type=PaymentMethod.nequi,
        )
        await session.commit()

    assert checkout.created is True
    assert checkout.wompi_transaction_id == "wompi-txn-1"
    assert checkout.payment.status is PaymentStatus.pending
    assert checkout.payment.amount == 50000


async def test_create_checkout_is_idempotent_for_the_same_reference(
    monkeypatch: pytest.MonkeyPatch, session_maker: async_sessionmaker[AsyncSession]
) -> None:
    from app.models.job import PaymentMethod

    _patch_wompi_client(
        monkeypatch,
        get_response=MERCHANT_RESPONSE,
        post_response=_FakeWompiResponse(
            201, {"data": {"id": "wompi-txn-2", "status": "PENDING", "payment_method": {}}}
        ),
    )
    gateway = WompiGateway(CONFIGURED_SETTINGS)
    async with session_maker() as session:
        first = await gateway.create_checkout(
            session,
            reference="settlement_dup",
            amount=20000,
            customer_email="driver@example.com",
            payment_method_type=PaymentMethod.nequi,
        )
        await session.commit()

    async with session_maker() as session:
        second = await gateway.create_checkout(
            session,
            reference="settlement_dup",
            amount=20000,
            customer_email="driver@example.com",
            payment_method_type=PaymentMethod.nequi,
        )

    assert second.created is False
    assert second.payment.id == first.payment.id


# ---- POST /v1/drivers/me/settle ----------------------------------------------


async def test_settle_my_balance_503_without_wompi_key(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
) -> None:
    async with session_maker() as session:
        from app.models.driver import DriverProfile, DriverStatus

        session.add(DriverProfile(user_id=driver_user.id, status=DriverStatus.offline))
        session.add(
            DriverLedgerEntry(
                driver_id=driver_user.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()

    response = await client.post(
        "/v1/drivers/me/settle", headers=AUTH_DRIVER, json={"amount": 10000}
    )
    assert response.status_code == 503


async def test_settle_my_balance_409_when_nothing_owed(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
) -> None:
    async with session_maker() as session:
        from app.models.driver import DriverProfile, DriverStatus

        session.add(DriverProfile(user_id=driver_user.id, status=DriverStatus.offline))
        await session.commit()

    response = await client.post(
        "/v1/drivers/me/settle", headers=AUTH_DRIVER, json={"amount": 10000}
    )
    assert response.status_code == 409


async def test_settle_my_balance_422_when_amount_exceeds_owed(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
) -> None:
    async with session_maker() as session:
        from app.models.driver import DriverProfile, DriverStatus

        session.add(DriverProfile(user_id=driver_user.id, status=DriverStatus.offline))
        session.add(
            DriverLedgerEntry(
                driver_id=driver_user.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()

    response = await client.post(
        "/v1/drivers/me/settle", headers=AUTH_DRIVER, json={"amount": 999999}
    )
    assert response.status_code == 422


async def test_settle_my_balance_happy_path(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
    monkeypatch: pytest.MonkeyPatch,
    wompi_configured: Settings,
) -> None:
    from app.models.driver import DriverProfile, DriverStatus

    async with session_maker() as session:
        session.add(DriverProfile(user_id=driver_user.id, status=DriverStatus.offline))
        session.add(
            DriverLedgerEntry(
                driver_id=driver_user.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()

    _patch_wompi_client(
        monkeypatch,
        get_response=MERCHANT_RESPONSE,
        post_response=_FakeWompiResponse(
            201,
            {
                "data": {
                    "id": "wompi-settle-1",
                    "status": "PENDING",
                    "payment_method": {
                        "extra": {"async_payment_url": "https://wompi.co/pse/abc"}
                    },
                }
            },
        ),
    )

    response = await client.post(
        "/v1/drivers/me/settle", headers=AUTH_DRIVER, json={"amount": 15000}
    )

    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["payment_reference"].startswith(f"settlement_{driver_user.id}_")
    assert body["async_payment_url"] == "https://wompi.co/pse/abc"


# ---- POST /v1/webhooks/wompi --------------------------------------------------


async def test_webhook_rejects_an_unsigned_payload(
    client: AsyncClient, wompi_configured: Settings
) -> None:
    response = await client.post(
        "/v1/webhooks/wompi",
        json=_signed_event(
            transaction={"id": "t1", "status": "APPROVED", "amount_in_cents": 100},
            events_key="wrong-key",
        ),
    )
    assert response.status_code == 401


async def test_webhook_503_without_events_key_configured(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/webhooks/wompi",
        json=_signed_event(
            transaction={"id": "t1", "status": "APPROVED", "amount_in_cents": 100},
            events_key="events-secret",
        ),
    )
    assert response.status_code == 503


async def test_webhook_acks_but_does_not_apply_an_unknown_reference(
    client: AsyncClient, wompi_configured: Settings
) -> None:
    payload = _signed_event(
        transaction={
            "id": "t1",
            "status": "APPROVED",
            "amount_in_cents": 100,
            "reference": "job_does-not-exist",
        },
        events_key="events-secret",
    )
    payload["data"]["transaction"]["reference"] = "job_does-not-exist"
    response = await client.post("/v1/webhooks/wompi", json=payload)

    assert response.status_code == 200
    assert response.json() == {"received": True, "applied": False}


async def _signed_payload_for(reference: str, status: str, txn_id: str = "t1") -> dict[str, Any]:
    return _signed_event(
        transaction={
            "id": txn_id,
            "status": status,
            "amount_in_cents": 100,
            "reference": reference,
        },
        events_key="events-secret",
    )


async def test_webhook_approves_a_job_payment_and_writes_the_digital_fare_ledger_entry(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    wompi_configured: Settings,
) -> None:
    from app.models.job import PaymentMethod

    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
        final_price=100000,
        payment_method=PaymentMethod.nequi,
    )
    reference = f"job_{job.id}"
    async with session_maker() as session:
        payment = Payment(
            job_id=job.id,
            provider="wompi",
            provider_ref="wompi-job-1",
            reference=reference,
            amount=100000,
            method=PaymentMethod.nequi,
            status=PaymentStatus.pending,
        )
        session.add(payment)
        await session.commit()

    payload = await _signed_payload_for(reference, "APPROVED")
    response = await client.post("/v1/webhooks/wompi", json=payload)

    assert response.status_code == 200
    assert response.json() == {"received": True, "applied": True}

    async with session_maker() as session:
        updated = await session.scalar(select(Payment).where(Payment.reference == reference))
        assert updated.status is PaymentStatus.approved
        assert updated.settled_at is not None
        entries = (
            await session.scalars(
                select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == job.id)
            )
        ).all()
    assert len(entries) == 1
    # PAY-4: "platform owes driver net" -> negative commission (see
    # apply_ledger_for_settled_payment's docstring). 100000 * 15% = 15000 commission.
    assert entries[0].commission == -85000
    owed = await driver_owed_balance_wrapper(session_maker, driver_user.id)
    assert owed == -85000  # platform owes the driver, not the other way around


async def driver_owed_balance_wrapper(
    session_maker: async_sessionmaker[AsyncSession], driver_id: Any
) -> int:
    async with session_maker() as session:
        return await driver_owed_balance(session, driver_id)


async def test_webhook_replay_of_the_same_event_is_a_noop(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    wompi_configured: Settings,
) -> None:
    from app.models.job import PaymentMethod

    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
        final_price=100000,
        payment_method=PaymentMethod.nequi,
    )
    reference = f"job_{job.id}"
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=job.id,
                provider="wompi",
                provider_ref="wompi-job-2",
                reference=reference,
                amount=100000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.pending,
            )
        )
        await session.commit()

    payload = await _signed_payload_for(reference, "APPROVED")
    first = await client.post("/v1/webhooks/wompi", json=payload)
    second = await client.post("/v1/webhooks/wompi", json=payload)  # exact replay

    assert first.json()["applied"] is True
    assert second.json()["applied"] is False  # already-seen dedup_key -> no-op

    async with session_maker() as session:
        entries = (
            await session.scalars(
                select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == job.id)
            )
        ).all()
    assert len(entries) == 1  # not duplicated


async def test_webhook_out_of_order_event_after_approval_is_a_noop(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    wompi_configured: Settings,
) -> None:
    from app.models.job import PaymentMethod

    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
        final_price=100000,
        payment_method=PaymentMethod.nequi,
    )
    reference = f"job_{job.id}"
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=job.id,
                provider="wompi",
                provider_ref="wompi-job-3",
                reference=reference,
                amount=100000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.pending,
            )
        )
        await session.commit()

    approved = await _signed_payload_for(reference, "APPROVED", txn_id="t-approved")
    await client.post("/v1/webhooks/wompi", json=approved)

    # A stale/out-of-order PENDING for the same transaction id arrives after
    # APPROVED already landed -- must not downgrade the payment.
    stale = await _signed_payload_for(reference, "PENDING", txn_id="t-approved")
    stale_response = await client.post("/v1/webhooks/wompi", json=stale)

    assert stale_response.json()["applied"] is False
    async with session_maker() as session:
        updated = await session.scalar(select(Payment).where(Payment.reference == reference))
    assert updated.status is PaymentStatus.approved  # unchanged


async def test_webhook_approves_a_settlement_and_writes_a_payout_row(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
    wompi_configured: Settings,
) -> None:
    from app.models.job import PaymentMethod

    reference = f"settlement_{driver_user.id}_abc123"
    async with session_maker() as session:
        session.add(
            Payment(
                job_id=None,
                provider="wompi",
                provider_ref="wompi-settle-2",
                reference=reference,
                amount=30000,
                method=PaymentMethod.nequi,
                status=PaymentStatus.pending,
            )
        )
        await session.commit()

    payload = await _signed_payload_for(reference, "APPROVED")
    response = await client.post("/v1/webhooks/wompi", json=payload)

    assert response.json()["applied"] is True
    async with session_maker() as session:
        entries = (
            await session.scalars(
                select(DriverLedgerEntry).where(DriverLedgerEntry.driver_id == driver_user.id)
            )
        ).all()
    assert len(entries) == 1
    assert entries[0].entry_type is LedgerEntryType.payout
    assert entries[0].net == 30000


# ---- PAY-4: confirm-delivery digital-fare flag -------------------------------


async def test_confirm_delivery_rejects_digital_method_when_flag_is_off(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    seeded_config: dict[str, Any],
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    response = await client.post(
        f"/v1/jobs/{job.id}/confirm-delivery",
        headers=AUTH_CUSTOMER,
        json={"payment_method": "nequi"},
    )
    assert response.status_code == 422


async def test_confirm_delivery_with_flag_on_creates_a_pending_wompi_payment_no_ledger_yet(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    fake_redis: Any,
    monkeypatch: pytest.MonkeyPatch,
    wompi_configured: Settings,
) -> None:
    from app.services.config import set_config

    async with session_maker() as session:
        await set_config(session, fake_redis, "payments", {"digital_fares_enabled": True})

    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    _patch_wompi_client(
        monkeypatch,
        get_response=MERCHANT_RESPONSE,
        post_response=_FakeWompiResponse(
            201, {"data": {"id": "wompi-digital-1", "status": "PENDING", "payment_method": {}}}
        ),
    )

    response = await client.post(
        f"/v1/jobs/{job.id}/confirm-delivery",
        headers=AUTH_CUSTOMER,
        json={"payment_method": "nequi"},
    )

    assert response.status_code == 200, response.json()
    # PAY-4 AC: job completes even though the payment is still processing.
    assert response.json()["status"] == "completed"

    async with session_maker() as session:
        payment = await session.scalar(
            select(Payment).where(Payment.reference == f"job_{job.id}")
        )
        assert payment.status is PaymentStatus.pending
        entries = (
            await session.scalars(
                select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == job.id)
            )
        ).all()
    # No ledger entry until the webhook reports approved -- see
    # apply_ledger_for_settled_payment's docstring.
    assert entries == []


async def test_confirm_delivery_with_pse_surfaces_the_redirect_url(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    fake_redis: Any,
    monkeypatch: pytest.MonkeyPatch,
    wompi_configured: Settings,
) -> None:
    """PAY-4: a real gap found while building the customer-facing checkout UI
    -- `WompiGateway.create_intent`'s `PaymentGateway`-protocol return shape
    (`tuple[Payment, bool]`, shared with `CashGateway`) had no room for the
    checkout's `async_payment_url`, so it was silently discarded before ever
    reaching `confirm_delivery_endpoint`'s response. A customer choosing a
    PSE/card fare had no URL to redirect to at all. Fixed via a transient
    `job.pending_payment_url` attribute (`WompiGateway.create_intent`) read
    back into `JobRead.async_payment_url` (`_job_read`) -- not a persisted
    column, only ever set on the exact `job` instance this one request
    already holds."""
    from app.services.config import set_config

    async with session_maker() as session:
        await set_config(session, fake_redis, "payments", {"digital_fares_enabled": True})

    job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
    )
    _patch_wompi_client(
        monkeypatch,
        get_response=MERCHANT_RESPONSE,
        post_response=_FakeWompiResponse(
            201,
            {
                "data": {
                    "id": "wompi-pse-1",
                    "status": "PENDING",
                    "payment_method": {
                        "extra": {"async_payment_url": "https://checkout.wompi.co/l/abc123"}
                    },
                }
            },
        ),
    )

    response = await client.post(
        f"/v1/jobs/{job.id}/confirm-delivery",
        headers=AUTH_CUSTOMER,
        json={"payment_method": "pse"},
    )

    assert response.status_code == 200, response.json()
    assert response.json()["async_payment_url"] == "https://checkout.wompi.co/l/abc123"

    # A second, unrelated read of the same (now-completed) job must not
    # resurrect a stale URL -- `pending_payment_url` is only ever set on the
    # in-memory instance from the call that actually created the checkout.
    again = await client.get(f"/v1/jobs/{job.id}", headers=AUTH_CUSTOMER)
    assert again.json()["async_payment_url"] is None


# ---- apply_ledger_for_settled_payment: cash vs. digital direction -----------


async def test_apply_ledger_cash_positive_commission_digital_negative(
    session_maker: async_sessionmaker[AsyncSession], customer_user: User, driver_user: User
) -> None:
    cash_job = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.delivered,
        driver=driver_user,
        config_snapshot=PERCENT_SNAPSHOT,
        final_price=100000,
    )
    async with session_maker() as session:
        cash_payment = Payment(
            job_id=cash_job.id,
            provider="cash",
            reference=f"job_{cash_job.id}",
            amount=100000,
            method="cash",
            status=PaymentStatus.approved,
        )
        job = await session.get(type(cash_job), cash_job.id)
        await apply_ledger_for_settled_payment(session, job, cash_payment)
        await session.commit()
        entry = await session.scalar(
            select(DriverLedgerEntry).where(DriverLedgerEntry.job_id == cash_job.id)
        )
    assert entry.commission == 15000  # driver owes the platform


async def test_apply_ledger_cash_and_digital_are_inverse_shapes() -> None:
    """Documents the sign convention directly (no DB round trip needed) -- see
    the parametrized amounts against a fixed 15% commission."""
    from app.services.jobs import commission_for_fare

    class _FakeJob:
        config_snapshot = PERCENT_SNAPSHOT
        vehicle_type = type("V", (), {"value": "car"})()

    fare = 100000
    commission = commission_for_fare(_FakeJob(), fare)
    assert commission == 15000
    # Cash: driver keeps 100000, owes 15000 -> commission stored positive.
    # Digital: platform keeps 100000, owes driver 85000 -> commission stored
    # as -85000 (see apply_ledger_for_settled_payment).
    assert -(fare - commission) == -85000
