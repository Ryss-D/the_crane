"""Request/response schemas for the fleets API (FLT-1 CRUD, FLT-2 ledger rollup,
FLT-4 driver invites)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.driver import TruckCapacity, TruckType
from app.schemas.driver import TruckRead


class FleetCreate(BaseModel):
    """POST /v1/fleets/me body."""

    name: str


class FleetRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    owner_user_id: uuid.UUID
    name: str
    created_at: datetime
    trucks: list[TruckRead] = []


# ---- FLT-2: ledger rollup + consolidated settlement --------------------------------


class FleetMemberBalance(BaseModel):
    driver_id: uuid.UUID
    name: str | None
    owed_balance: int


class FleetBalanceRead(BaseModel):
    """Consolidated balance across every driver whose truck belongs to the fleet."""

    fleet_id: uuid.UUID
    owed_balance: int
    members: list[FleetMemberBalance]


class FleetSettleRequest(BaseModel):
    """POST /v1/admin/fleets/{fleet_id}/settle body — one payment apportioned across
    the fleet's member drivers, proportional to each driver's current owed balance
    (largest-remainder rounding so the per-driver shares sum exactly to `amount`)."""

    amount: int
    note: str | None = None


class FleetSettlementEntry(BaseModel):
    driver_id: uuid.UUID
    ledger_entry_id: uuid.UUID
    amount: int


class FleetSettleResponse(BaseModel):
    fleet_id: uuid.UUID
    total_amount: int
    entries: list[FleetSettlementEntry]


# ---- FLT-4: phone invite -> signup lands pre-linked ---------------------------


class InviteCreate(BaseModel):
    """POST /v1/fleets/me/invites body.

    Mirrors DriverRegisterRequest's truck fields exactly (same types, reused from
    app/schemas/driver.py) -- this pre-provisions the same Truck row AUTH-5's own
    registration would otherwise create, just with no driver_id yet.
    """

    phone: str
    plate: str
    truck_type: TruckType
    capacity: TruckCapacity


class InviteRead(BaseModel):
    """Returned by POST /v1/fleets/me/invites and GET /v1/fleets/me/invites.

    `invite_token` is what the invited driver passes as `invite_token` on
    POST /v1/drivers/me/register to redeem it.
    """

    invite_token: uuid.UUID
    truck_id: uuid.UUID
    phone: str


class AdminFleetListItem(BaseModel):
    """GET /v1/admin/fleets row — enough to pick a fleet before drilling into its
    balance (GET /v1/admin/fleets/{id}/balance) or settling it."""

    id: uuid.UUID
    owner_user_id: uuid.UUID
    owner_name: str | None
    name: str
    truck_count: int
    owed_balance: int
    created_at: datetime
