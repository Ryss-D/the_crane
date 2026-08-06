"""Request/response schemas for the drivers API (AUTH-5 registration, DSP-1 status,
driver-facing earnings/balance)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.driver import DriverStatus, TruckCapacity, TruckType


class DriverRegisterRequest(BaseModel):
    """POST /v1/drivers/me/register body (AUTH-5).

    Document upload to object storage is out of scope for this task — license/truck
    photo URLs are accepted as plain strings for now; a later task wires real upload
    and replaces these with signed URLs from that flow.
    """

    plate: str
    truck_type: TruckType
    capacity: TruckCapacity
    license_url: str | None = None
    truck_photo_url: str | None = None


class TruckRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    plate: str
    type: TruckType
    capacity: TruckCapacity
    driver_id: uuid.UUID | None
    fleet_id: uuid.UUID | None


class DriverProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    status: DriverStatus
    verified: bool
    license_url: str | None
    truck_photo_url: str | None
    rating_avg: float | None
    truck: TruckRead | None = None


class DriverStatusUpdate(BaseModel):
    """PATCH /v1/drivers/me/status body (DSP-1).

    lat/lng are required when going `available` (they seed the Redis geo entry);
    `offline` ignores them. `on_job` is not a valid value here — it's set internally
    by the accept flow (DSP-3).
    """

    status: DriverStatus
    lat: float | None = None
    lng: float | None = None


class DriverSettlementRead(BaseModel):
    """One entry in GET /v1/drivers/me/balance's recent-settlements list — built
    from a `payout` driver_ledger row (see app/services/ledger.py's docstring on
    the earning/payout/adjustment convention)."""

    id: str
    amount_cents: int
    settled_at: datetime
    note: str | None


class DriverBalanceRead(BaseModel):
    """GET /v1/drivers/me/balance (DRV-5): current owed balance, the settlement
    cap it's gated against (null if disabled), and recent settlement history."""

    owed_cents: int
    balance_cap_cents: int | None
    recent_settlements: list[DriverSettlementRead]
