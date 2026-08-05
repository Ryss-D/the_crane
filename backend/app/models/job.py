"""Job domain models (JOB-1): jobs, job_offers, customer_vehicles, location snapshots.

Geometry note: pickup/dropoff are stored as plain lat/lng float columns for now, NOT
PostGIS geometry. geoalchemy2 on sqlite would require SpatiaLite (a native extension),
breaking the service-free pytest setup, and a dialect-conditional column type would fork
the model and migrations. PostGIS `geometry(Point, 4326)` columns + a GiST index on
pickup arrive with the dispatch geo work (DSP-1), backfilled from these floats.
"""

import enum
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JSONValue


class VehicleType(enum.StrEnum):
    moto = "moto"
    car = "car"
    suv = "suv"


class JobStatus(enum.StrEnum):
    requested = "requested"
    matching = "matching"
    assigned = "assigned"
    en_route_pickup = "en_route_pickup"
    arrived_pickup = "arrived_pickup"
    loading = "loading"
    in_transit = "in_transit"
    delivered = "delivered"
    completed = "completed"
    cancelled = "cancelled"
    no_drivers = "no_drivers"


class PaymentMethod(enum.StrEnum):
    cash = "cash"
    card = "card"
    pse = "pse"
    nequi = "nequi"
    wallet = "wallet"


class OfferResponse(enum.StrEnum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    timeout = "timeout"


class CustomerVehicle(Base):
    __tablename__ = "customer_vehicles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    type: Mapped[VehicleType] = mapped_column(
        Enum(VehicleType, name="vehicle_type", native_enum=False, length=20)
    )
    make: Mapped[str | None] = mapped_column(String(60))
    model: Mapped[str | None] = mapped_column(String(60))
    plate: Mapped[str | None] = mapped_column(String(16))


class Job(Base):
    __tablename__ = "jobs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    driver_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    vehicle_type: Mapped[VehicleType] = mapped_column(
        Enum(VehicleType, name="vehicle_type", native_enum=False, length=20)
    )
    status: Mapped[JobStatus] = mapped_column(
        Enum(JobStatus, name="job_status", native_enum=False, length=20),
        default=JobStatus.requested,
        index=True,
    )
    # Plain floats until DSP-1 (see module docstring).
    pickup_lat: Mapped[float] = mapped_column()
    pickup_lng: Mapped[float] = mapped_column()
    dropoff_lat: Mapped[float] = mapped_column()
    dropoff_lng: Mapped[float] = mapped_column()
    pickup_address: Mapped[str] = mapped_column(Text)
    dropoff_address: Mapped[str] = mapped_column(Text)
    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    # Money is COP: no decimals, Numeric(12, 0).
    quoted_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 0))
    final_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 0))
    payment_method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod, name="payment_method", native_enum=False, length=20),
        default=PaymentMethod.cash,
    )
    # Pricing/commission config values the job was quoted with (JOB-5 writes it).
    config_snapshot: Mapped[dict[str, Any] | None] = mapped_column(JSONValue, nullable=True)
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    picked_up_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancel_reason: Mapped[str | None] = mapped_column(String(255))
    share_token: Mapped[uuid.UUID] = mapped_column(unique=True, default=uuid.uuid4)


class JobOffer(Base):
    __tablename__ = "job_offers"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id"), index=True)
    driver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    offered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    response: Mapped[OfferResponse] = mapped_column(
        Enum(OfferResponse, name="offer_response", native_enum=False, length=20),
        default=OfferResponse.pending,
    )


class DriverLocationSnapshot(Base):
    __tablename__ = "driver_location_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id"), index=True)
    driver_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    lat: Mapped[float] = mapped_column()
    lng: Mapped[float] = mapped_column()
    job_status: Mapped[JobStatus] = mapped_column(
        Enum(JobStatus, name="job_status", native_enum=False, length=20)
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
