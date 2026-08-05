"""Jobs API (JOB-4/5/6 + TRK-6 poll half): quote, create, read/list, cancel,
driver status advance, customer confirm-delivery, and the public share-token
tracking endpoint (`track_router`, mounted at /v1/track in main.py).
"""

import uuid
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import CurrentUser
from app.models.driver import Truck
from app.models.job import CustomerVehicle, DriverLocationSnapshot, Job, JobStatus
from app.models.user import User, UserRole
from app.schemas.job import (
    JobCreate,
    JobListResponse,
    JobRead,
    JobStatusUpdate,
    LatLng,
    QuoteRequest,
    QuoteResponse,
    TrackDriver,
    TrackResponse,
)
from app.services import pricing
from app.services.config import RedisLike, get_config
from app.services.jobs import (
    DRIVER_PROGRESS_STATUSES,
    JobAccessError,
    JobEventHook,
    JobTransitionError,
    cancel_job,
    confirm_delivery,
    get_job_event_hook,
    transition,
)

router = APIRouter(prefix="/jobs", tags=["jobs"])
track_router = APIRouter(prefix="/track", tags=["track"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]
RedisDep = Annotated[RedisLike, Depends(get_redis)]
EventHookDep = Annotated[JobEventHook, Depends(get_job_event_hook)]
DirectionsDep = Annotated[pricing.DirectionsClient, Depends(pricing.get_directions_client)]

# Statuses in which the public track page shows the (limited) driver block.
_TRACK_DRIVER_VISIBLE = frozenset(
    {
        JobStatus.assigned,
        JobStatus.en_route_pickup,
        JobStatus.arrived_pickup,
        JobStatus.loading,
        JobStatus.in_transit,
        JobStatus.delivered,
    }
)


async def _get_job_or_404(session: AsyncSession, job_id: uuid.UUID) -> Job:
    job = await session.get(Job, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    return job


def _require_view_access(job: Job, user: User) -> None:
    """Customer sees own jobs, driver the ones assigned to them, admin any."""
    if user.role is UserRole.admin or user.id in (job.customer_id, job.driver_id):
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN, detail="You do not have access to this job"
    )


@router.post("/quote", response_model=QuoteResponse)
async def create_quote(
    body: QuoteRequest,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    directions: DirectionsDep,
) -> dict[str, Any]:
    """JOB-4: price a trip from live config; the quote is Redis-cached for 10 minutes."""
    return await pricing.build_quote(
        session,
        redis,
        directions,
        vehicle_type=body.vehicle_type,
        pickup=(body.pickup.lat, body.pickup.lng),
        dropoff=(body.dropoff.lat, body.dropoff.lng),
    )


@router.post("", response_model=JobRead, status_code=status.HTTP_201_CREATED)
async def create_job(
    body: JobCreate,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
) -> Job:
    """JOB-5: create a job from a quote; snapshots config and moves to `matching`."""
    quote = await pricing.pop_quote(redis, body.quote_id)
    if quote is None:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Quote expired or unknown — request a new quote",
        )
    if quote["vehicle_type"] != body.vehicle_type.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Quote was issued for a different vehicle type",
        )
    if body.customer_vehicle_id is not None:
        vehicle = await session.scalar(
            select(CustomerVehicle).where(
                CustomerVehicle.id == body.customer_vehicle_id,
                CustomerVehicle.user_id == user.id,
            )
        )
        if vehicle is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Customer vehicle not found"
            )

    # Snapshot the pricing/commission values in effect NOW: completion (LED-1)
    # reads commission from here, so later config edits never rewrite history.
    pricing_config = await get_config(session, redis, "pricing")
    commission_config = await get_config(session, redis, "commission")
    if pricing_config is None or commission_config is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Platform pricing/commission config is not seeded",
        )

    job = Job(
        customer_id=user.id,
        vehicle_type=body.vehicle_type,
        status=JobStatus.requested,
        pickup_lat=body.pickup.lat,
        pickup_lng=body.pickup.lng,
        dropoff_lat=body.dropoff.lat,
        dropoff_lng=body.dropoff.lng,
        pickup_address=body.pickup.address,
        dropoff_address=body.dropoff.address,
        distance_km=quote["distance_km"],
        quoted_price=quote["price"],
        config_snapshot={"pricing": pricing_config, "commission": commission_config},
    )
    session.add(job)
    await transition(session, job, JobStatus.matching, actor=user, event_hook=event_hook)
    # DSP-2 hook site: dispatch.request_drivers(job) starts the sequential-offer
    # loop here once the dispatch service lands.
    return job


@router.get("", response_model=JobListResponse)
async def list_jobs(
    user: CurrentUser,
    session: SessionDep,
    role: Literal["customer", "driver"] = "customer",
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> dict[str, Any]:
    """JOB-5: the caller's job history (as customer or driver), newest first."""
    owner_column = Job.customer_id if role == "customer" else Job.driver_id
    total = await session.scalar(
        select(func.count()).select_from(Job).where(owner_column == user.id)
    )
    jobs = (
        await session.scalars(
            select(Job)
            .where(owner_column == user.id)
            .order_by(Job.requested_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return {"items": jobs, "total": total or 0, "limit": limit, "offset": offset}


@router.get("/{job_id}", response_model=JobRead)
async def get_job(job_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Job:
    """JOB-5: customer sees own, driver sees assigned, admin any."""
    job = await _get_job_or_404(session, job_id)
    _require_view_access(job, user)
    return job


@router.post("/{job_id}/cancel", response_model=JobRead)
async def cancel_job_endpoint(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
) -> Job:
    """JOB-5: cancel per JOB-3 rules (customer -> cancelled, driver -> back to matching)."""
    job = await _get_job_or_404(session, job_id)
    try:
        return await cancel_job(session, redis, job, actor=user, event_hook=event_hook)
    except JobAccessError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except JobTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{job_id}/status", response_model=JobRead)
async def update_job_status(
    job_id: uuid.UUID,
    body: JobStatusUpdate,
    user: CurrentUser,
    session: SessionDep,
    event_hook: EventHookDep,
) -> Job:
    """JOB-6: the assigned driver advances the machine (optionally with a location fix)."""
    job = await _get_job_or_404(session, job_id)
    if job.driver_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the assigned driver may update job status",
        )
    if body.status is JobStatus.completed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Completion is confirmed by the customer (confirm-delivery)",
        )
    if body.status not in DRIVER_PROGRESS_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Drivers cannot set status {body.status.value}",
        )
    try:
        return await transition(
            session,
            job,
            body.status,
            actor=user,
            lat=body.lat,
            lng=body.lng,
            event_hook=event_hook,
        )
    except JobTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{job_id}/confirm-delivery", response_model=JobRead)
async def confirm_delivery_endpoint(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    event_hook: EventHookDep,
) -> Job:
    """CUS-5/LED-1: customer confirms delivery + cash payment -> completed + accrual."""
    job = await _get_job_or_404(session, job_id)
    try:
        return await confirm_delivery(session, job, actor=user, event_hook=event_hook)
    except JobAccessError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except JobTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@track_router.get("/{share_token}", response_model=TrackResponse)
async def track_job(share_token: str, session: SessionDep) -> TrackResponse:
    """TRK-6 (poll half): public tracking by share token — no auth, minimal PII.

    Exposes only the job status, pickup/dropoff coords, the driver's first name
    + truck plate once assigned, and the last known driver location snapshot.
    The WebSocket half arrives with the TRK tasks.
    """
    try:
        token = uuid.UUID(share_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found") from exc
    job = await session.scalar(select(Job).where(Job.share_token == token))
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    driver: TrackDriver | None = None
    driver_location: LatLng | None = None
    if job.driver_id is not None and job.status in _TRACK_DRIVER_VISIBLE:
        driver_user = await session.get(User, job.driver_id)
        truck = await session.scalar(select(Truck).where(Truck.driver_id == job.driver_id))
        first_name = driver_user.name.split()[0] if driver_user and driver_user.name else None
        driver = TrackDriver(first_name=first_name, truck_plate=truck.plate if truck else None)
        snapshot = await session.scalar(
            select(DriverLocationSnapshot)
            .where(DriverLocationSnapshot.job_id == job.id)
            .order_by(DriverLocationSnapshot.created_at.desc())
            .limit(1)
        )
        if snapshot is not None:
            driver_location = LatLng(lat=snapshot.lat, lng=snapshot.lng)

    return TrackResponse(
        status=job.status,
        pickup=LatLng(lat=job.pickup_lat, lng=job.pickup_lng),
        dropoff=LatLng(lat=job.dropoff_lat, lng=job.dropoff_lng),
        driver=driver,
        driver_location=driver_location,
    )
