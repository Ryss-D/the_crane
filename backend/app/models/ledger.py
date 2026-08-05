"""Money spine tables (LED-1, tables only): payments, payment_events, driver_ledger, payouts.

Accrual/settlement business logic lands with LED-1's second half and LED-2+; nothing here
writes rows yet. Money columns are COP: Numeric(12, 0), no decimals.
"""

import enum
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JSONValue
from app.models.job import PaymentMethod


class PaymentProvider(enum.StrEnum):
    cash = "cash"
    wompi = "wompi"
    mercadopago = "mercadopago"


class PaymentStatus(enum.StrEnum):
    pending = "pending"
    processing = "processing"
    approved = "approved"
    declined = "declined"
    expired = "expired"
    refunded = "refunded"


class LedgerEntryType(enum.StrEnum):
    earning = "earning"
    payout = "payout"
    adjustment = "adjustment"


class PayoutStatus(enum.StrEnum):
    pending = "pending"
    paid = "paid"


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id"), index=True)
    provider: Mapped[PaymentProvider] = mapped_column(
        Enum(PaymentProvider, name="payment_provider", native_enum=False, length=20)
    )
    provider_ref: Mapped[str | None] = mapped_column(String(128))
    reference: Mapped[str] = mapped_column(String(64), unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 0))
    currency: Mapped[str] = mapped_column(String(3), default="COP")
    method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod, name="payment_method", native_enum=False, length=20)
    )
    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status", native_enum=False, length=20),
        default=PaymentStatus.pending,
    )
    raw_webhook: Mapped[dict[str, Any] | None] = mapped_column(JSONValue, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class PaymentEvent(Base):
    __tablename__ = "payment_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    payment_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("payments.id"), index=True)
    payload: Mapped[dict[str, Any]] = mapped_column(JSONValue)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Payout(Base):
    __tablename__ = "payouts"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    driver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 0))
    period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    period_end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[PayoutStatus] = mapped_column(
        Enum(PayoutStatus, name="payout_status", native_enum=False, length=20),
        default=PayoutStatus.pending,
    )
    provider_ref: Mapped[str | None] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DriverLedgerEntry(Base):
    __tablename__ = "driver_ledger"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    driver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    job_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("jobs.id"))
    gross: Mapped[Decimal] = mapped_column(Numeric(12, 0))
    commission: Mapped[Decimal] = mapped_column(Numeric(12, 0))
    net: Mapped[Decimal] = mapped_column(Numeric(12, 0))
    entry_type: Mapped[LedgerEntryType] = mapped_column(
        Enum(LedgerEntryType, name="ledger_entry_type", native_enum=False, length=20)
    )
    payout_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("payouts.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
