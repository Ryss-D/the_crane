"""Request/response schemas for the admin API (ADM-2)."""

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict

from app.models.driver import DriverStatus
from app.models.job import JobStatus, OfferResponse, PaymentMethod, VehicleType
from app.models.ledger import LedgerEntryType, PaymentStatus
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
    license_url: str | None
    truck_photo_url: str | None


class AdminDriverListResponse(BaseModel):
    items: list[AdminDriverRead]
    total: int
    limit: int
    offset: int


# ---- Jobs (ADM-2 / ADM-5) ------------------------------------------------------


class JobOfferRead(BaseModel):
    id: uuid.UUID
    driver_id: uuid.UUID
    driver_name: str | None
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


class AdminJobListItem(BaseModel):
    """GET /v1/admin/jobs list item — every JobRead field plus names joined
    from users. Built by hand (not subclassing JobRead) for the same reason
    as JobAdminDetail below: these two name fields aren't ORM attributes on
    Job, so from_attributes can't reach them — the endpoint constructs each
    item from a JobRead dict merged with a batch user-name lookup."""

    id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str | None
    customer_phone: str | None
    driver_id: uuid.UUID | None
    driver_name: str | None
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
    # PAY-4 follow-up (2026-08-31): the *actual* state of the job's Payment row
    # (most recent by created_at, though a job only ever has at most one --
    # `payment_reference` is deterministic per job_id), distinct from
    # `payment_method` above which is only what the customer requested. `None`
    # when no Payment row exists yet (cash jobs settle synchronously so this is
    # rarely null for them in practice, but a not-yet-delivered job has none).
    payment_status: PaymentStatus | None
    config_snapshot: dict[str, Any] | None
    requested_at: datetime
    assigned_at: datetime | None
    picked_up_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    cancel_reason: str | None
    share_token: uuid.UUID


class AdminJobListResponse(BaseModel):
    items: list[AdminJobListItem]
    total: int
    limit: int
    offset: int


class JobAdminDetail(AdminJobListItem):
    """GET /v1/admin/jobs/{id} — AdminJobListItem plus the full offer trail
    and recent location snapshots."""

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


class DriverLedgerEntryListResponse(BaseModel):
    items: list[DriverLedgerEntryRead]
    total: int
    limit: int
    offset: int
