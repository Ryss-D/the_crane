"""Request/response schemas for the customer saved-vehicles API (CUS-6)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.job import VehicleType


class VehicleCreate(BaseModel):
    """POST /v1/me/vehicles body."""

    type: VehicleType
    make: str | None = None
    model: str | None = None
    plate: str


class VehicleUpdate(BaseModel):
    """PATCH /v1/me/vehicles/{id} body — any subset; absent fields are untouched."""

    type: VehicleType | None = None
    make: str | None = None
    model: str | None = None
    plate: str | None = None


class VehicleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: VehicleType
    make: str | None
    model: str | None
    plate: str | None
    created_at: datetime
