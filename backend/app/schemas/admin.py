"""Request/response schemas for the admin API (ADM-2)."""

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict

from app.models.driver import DriverStatus
from app.models.job import JobStatus, OfferResponse, PaymentMethod, VehicleType
from app.models.ledger import LedgerEntryType
from app.schemas.driver import TruckRead

# ---- Config (ADM-2 / ADM-3) --------------------------------------------------


class ConfigAuditRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    old_value: Any | None
    new_value: Any
    changed_by: uuid.UUID | None
    changed_at: datetime


class ConfigRead(BaseModel):
    key: str
    value: Any
    updated_by: uuid.UUID | None
    updated_at: datetime
    audit: list[ConfigAuditRead]


class ConfigUpdate(BaseModel):
    """PUT /v1/admin/config/{key} body — upserts (unknown keys create a new row)."""

    value: Any


# ---- Drivers (ADM-2 / ADM-4) --------------------------------------------------


class AdminDriverRead(BaseModel):
    user_id: uuid.UUID
    name: str | None
    phone: str | None
    email: str | None
    status: DriverStatus
    verified: bool
    rating_avg: float | None
    truck: TruckRead | None
    owed_balance: int


class AdminDriverListResponse(BaseModel):
    items: list[AdminDriverRead]
    total: int
    limit: int
    offset: int


# ---- Jobs (ADM-2 / ADM-5) ------------------------------------------------------


class JobOfferRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    driver_id: uuid.UUID
    offered_at: datetime
    responded_at: datetime | None
    response: OfferResponse


class DriverLocationSnapshotRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    driver_id: uuid.UUID
    lat: float
    lng: float
    job_status: JobStatus
    created_at: datetime


class JobAdminDetail(BaseModel):
    """GET /v1/admin/jobs/{id} — the job plus its full offer trail and recent
    location snapshots. Built by hand from JobRead + these two lists rather than
    subclassing JobRead, since Pydantic's from_attributes validation can't reach
    across relationships that aren't declared on the ORM model."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    customer_id: uuid.UUID
    driver_id: uuid.UUID | None
    vehicle_type: VehicleType
    status: JobStatus
    pickup_lat: float
    pickup_lng: float
    dropoff_lat: float
    dropoff_lng: float
    pickup_address: str
    dropoff_address: str
    distance_km: float | None
    quoted_price: int | None
    final_price: int | None
    payment_method: PaymentMethod
    config_snapshot: dict[str, Any] | None
    requested_at: datetime
    assigned_at: datetime | None
    picked_up_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    cancel_reason: str | None
    share_token: uuid.UUID
    offers: list[JobOfferRead]
    location_snapshots: list[DriverLocationSnapshotRead]


# ---- Ledger (ADM-2 / ADM-6) -----------------------------------------------------


class AdminLedgerRead(BaseModel):
    driver_id: uuid.UUID
    name: str | None
    owed_balance: int


class AdminLedgerListResponse(BaseModel):
    items: list[AdminLedgerRead]
    total: int
    limit: int
    offset: int


class LedgerSettleRequest(BaseModel):
    """POST /v1/admin/ledger/{driver_id}/settle body — records a payout entry that
    reduces the driver's owed balance."""

    amount: int
    note: str | None = None


class DriverLedgerEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    driver_id: uuid.UUID
    job_id: uuid.UUID | None
    gross: int
    commission: int
    net: int
    entry_type: LedgerEntryType
    note: str | None
    created_at: datetime
