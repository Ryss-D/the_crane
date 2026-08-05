"""Request/response schemas for the jobs API (JOB-4/5/6, TRK-6 poll half) and the
realtime WS payloads built on top of them (TRK-1/2/3/6 — app/services/realtime.py,
app/api/ws.py)."""

import uuid
from datetime import datetime
from typing import Any, Literal

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


# ---- WS push payloads (TRK-1/2/3/6) ----------------------------------------------
#
# Server -> client message shapes. Client -> server messages (subscribe/unsubscribe/
# location/pong) are small enough to stay as plain dicts, validated inline in
# app/api/ws.py rather than via schemas here.


class JobEventPayload(BaseModel):
    """WS `job_event` push to a job's authenticated subscribers (customer + assigned
    driver): enough of the job to update a tracking UI without a follow-up GET.
    Mirrors JobRead's status/price/timestamp fields; omits pickup/dropoff text and
    config_snapshot since a subscribed client already fetched those via GET
    /v1/jobs/{id}. NOT sent to public share-token viewers — see JobTrackEvent."""

    model_config = ConfigDict(from_attributes=True)

    type: Literal["job_event"] = "job_event"
    job_id: uuid.UUID
    status: JobStatus
    old_status: JobStatus
    driver_id: uuid.UUID | None
    quoted_price: int | None
    final_price: int | None
    requested_at: datetime
    assigned_at: datetime | None
    picked_up_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    cancel_reason: str | None


class JobTrackEvent(BaseModel):
    """WS `job_event` push to public share-token viewers (TRK-6 WS half) — same
    fields TrackResponse already exposes over the poll endpoint (status + driver
    first name/plate), nothing more. No price, no ids beyond the job itself."""

    type: Literal["job_event"] = "job_event"
    job_id: uuid.UUID
    status: JobStatus
    driver: TrackDriver | None


class DriverLocationEvent(BaseModel):
    """WS `driver_location` push — identical payload to both the full job channel
    and the public track channel, since a live position is exactly what the poll
    endpoint's `driver_location` field already exposes (no extra PII either way)."""

    type: Literal["driver_location"] = "driver_location"
    job_id: uuid.UUID
    lat: float
    lng: float


class JobOfferEvent(BaseModel):
    """WS `job_offer` push straight to the offered driver's live connections
    (TRK-3's offer_notifier). Background/no-socket drivers are covered by FCM later."""

    type: Literal["job_offer"] = "job_offer"
    job_id: uuid.UUID
    offer_id: uuid.UUID
    vehicle_type: VehicleType
    pickup: LatLng
    dropoff: LatLng
    quoted_price: int | None
    expires_in_seconds: int
