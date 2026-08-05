"""Request/response schemas for the jobs API (JOB-4/5/6, TRK-6 poll half)."""

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict

from app.models.job import JobStatus, PaymentMethod, VehicleType
from app.services.pricing import QUOTE_TTL_SECONDS


class LatLng(BaseModel):
    lat: float
    lng: float


class LocationIn(LatLng):
    """A point plus its human-readable address (job creation)."""

    address: str


class QuoteRequest(BaseModel):
    vehicle_type: VehicleType
    pickup: LatLng
    dropoff: LatLng


class QuoteResponse(BaseModel):
    quote_id: uuid.UUID
    vehicle_type: VehicleType
    price: int  # COP, no decimals
    distance_km: float
    eta_minutes: int
    expires_in_seconds: int = QUOTE_TTL_SECONDS


class JobCreate(BaseModel):
    quote_id: uuid.UUID
    vehicle_type: VehicleType
    pickup: LocationIn
    dropoff: LocationIn
    customer_vehicle_id: uuid.UUID | None = None


class JobRead(BaseModel):
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
    quoted_price: int | None  # COP
    final_price: int | None  # COP
    payment_method: PaymentMethod
    config_snapshot: dict[str, Any] | None
    requested_at: datetime
    assigned_at: datetime | None
    picked_up_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    cancel_reason: str | None
    share_token: uuid.UUID


class JobListResponse(BaseModel):
    items: list[JobRead]
    total: int
    limit: int
    offset: int


class JobStatusUpdate(BaseModel):
    """POST /v1/jobs/{id}/status body — assigned driver advances the machine."""

    status: JobStatus
    lat: float | None = None
    lng: float | None = None


class TrackDriver(BaseModel):
    """The only driver PII a public share link exposes."""

    first_name: str | None
    truck_plate: str | None


class TrackResponse(BaseModel):
    """Public tracking payload (GET /v1/track/{share_token}) — no auth, minimal PII."""

    status: JobStatus
    pickup: LatLng
    dropoff: LatLng
    driver: TrackDriver | None
    driver_location: LatLng | None
