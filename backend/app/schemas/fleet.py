"""Request/response schemas for the fleets API (FLT-1 CRUD, FLT-2 ledger rollup)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

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
