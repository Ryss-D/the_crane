"""Jobs API (JOB-4/5/6 + TRK-6 poll half): quote, create, read/list, cancel,
driver status advance, customer confirm-delivery, and the public share-token
tracking endpoint (`track_router`, mounted at /v1/track in main.py).
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import CurrentUser
from app.models.driver import DriverProfile, DriverStatus, Truck
from app.models.job import (
    CustomerVehicle,
    DriverLocationSnapshot,
    Job,
    JobOffer,
    JobStatus,
    OfferResponse,
)
from app.models.user import User, UserRole
from app.schemas.job import (
    JobCreate,
    JobDriverInfo,
    JobListResponse,
    JobRead,
    JobStatusUpdate,
    LatLng,
    QuoteRequest,
    QuoteResponse,
    TrackDriver,
    TrackResponse,
)
from app.services import dispatch, pricing
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
OfferNotifierDep = Annotated[dispatch.OfferNotifier, Depends(dispatch.get_offer_notifier)]
DirectionsDep = Annotated[pricing.DirectionsClient, Depends(pricing.get_directions_client)]


def _as_aware(dt: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC (all stamps are UTC)."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


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


async def _job_read(session: AsyncSession, job: Job) -> JobRead:
    """Every job-returning endpoint goes through this instead of `return job`
    directly, so the assigned driver's summary (name/phone/truck/rating) is
    actually populated -- `Job` has no ORM relationship for it, so this is
    the one extra query (skipped once there's no driver yet) that fills in
    `JobRead.driver`, the same fields `track_job` below already fetches for
    the public tracking view."""
    read = JobRead.model_validate(job)
    if job.driver_id is None:
        return read
    driver_user = await session.get(User, job.driver_id)
    profile = await session.scalar(
        select(DriverProfile).where(DriverProfile.user_id == job.driver_id)
    )
    truck = await session.scalar(select(Truck).where(Truck.driver_id == job.driver_id))
    if truck is None:
        # Shouldn't happen (a job only ever gets driver_id from an accepted
        # offer, which requires a registered truck) -- fall back to no
        # driver summary rather than a bogus one if it somehow did.
        return read
    return read.model_copy(
        update={
            "driver": JobDriverInfo(
                id=job.driver_id,
                name=driver_user.name if driver_user else None,
                phone=driver_user.phone if driver_user else None,
                truck_plate=truck.plate,
                truck_type=truck.type,
                rating_avg=float(profile.rating_avg)
                if profile and profile.rating_avg is not None
                else None,
            )
        }
    )


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
    offer_notifier: OfferNotifierDep,
) -> JobRead:
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
    # DSP-2: run synchronously (direct await) rather than backgrounded — Starlette's
    # BackgroundTasks execute before the ASGI response is actually handed back under
    # test transports anyway (no perceived latency win there), and a truly detached
    # asyncio.create_task would outlive this request-scoped `session`. Deterministic
    # and simple wins for an MVP-scale matcher; a queue/worker can take over later.
    await dispatch.start_dispatch(session, redis, job, event_hook, offer_notifier)
    return await _job_read(session, job)


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
    return {
        "items": [await _job_read(session, job) for job in jobs],
        "total": total or 0,
        "limit": limit,
        "offset": offset,
    }


@router.get("/{job_id}", response_model=JobRead)
async def get_job(job_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> JobRead:
    """JOB-5: customer sees own, driver sees assigned, admin any."""
    job = await _get_job_or_404(session, job_id)
    _require_view_access(job, user)
    return await _job_read(session, job)


@router.post("/{job_id}/cancel", response_model=JobRead)
async def cancel_job_endpoint(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
    offer_notifier: OfferNotifierDep,
) -> JobRead:
    """JOB-5: cancel per JOB-3 rules (customer -> cancelled, driver -> back to matching)."""
    job = await _get_job_or_404(session, job_id)
    try:
        job = await cancel_job(session, redis, job, actor=user, event_hook=event_hook)
    except JobAccessError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except JobTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    if job.status is JobStatus.matching:
        # DSP-2 hook site: a driver cancel released the job back to the pool — re-run
        # the offer loop. The ex-driver's own (accepted) job_offers row already
        # excludes them from start_dispatch's candidate search, no special-casing.
        await dispatch.start_dispatch(session, redis, job, event_hook, offer_notifier)
    return await _job_read(session, job)


async def _get_pending_offer_or_403(
    session: AsyncSession, job_id: uuid.UUID, driver_id: uuid.UUID
) -> JobOffer:
    offer = await session.scalar(
        select(JobOffer).where(
            JobOffer.job_id == job_id,
            JobOffer.driver_id == driver_id,
            JobOffer.response == OfferResponse.pending,
        )
    )
    if offer is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="No pending offer for this driver"
        )
    return offer


@router.post("/{job_id}/accept", response_model=JobRead)
async def accept_job(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
) -> JobRead:
    """DSP-3: the offered driver accepts — first accept wins, job -> assigned.

    Race safety: on Postgres this re-reads the job with SELECT ... FOR UPDATE,
    serializing concurrent acceptors on the row. SQLite has no row-level locking
    (and the test harness shares one connection/StaticPool across sessions), so the
    actual exclusivity guarantee for BOTH dialects is the atomic conditional UPDATE
    below — its WHERE clause (status='matching' AND driver_id IS NULL) can only ever
    match for one writer regardless of lock semantics, so the FOR UPDATE re-read is
    belt-and-suspenders on Postgres rather than the sole safety net.
    """
    job = await _get_job_or_404(session, job_id)
    offer = await _get_pending_offer_or_403(session, job.id, user.id)

    dispatch_config = await get_config(session, redis, "dispatch") or {}
    ttl_seconds = dispatch_config.get("offer_ttl_seconds", dispatch.DEFAULT_OFFER_TTL_SECONDS)
    if (datetime.now(UTC) - _as_aware(offer.offered_at)).total_seconds() > ttl_seconds:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Offer expired")

    stmt = select(Job).where(Job.id == job.id)
    if session.bind is not None and session.bind.dialect.name == "postgresql":
        stmt = stmt.with_for_update()
    job = await session.scalar(stmt)

    claim = await session.execute(
        update(Job)
        .where(Job.id == job.id, Job.status == JobStatus.matching, Job.driver_id.is_(None))
        .values(driver_id=user.id)
    )
    await session.commit()
    if claim.rowcount != 1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Job is no longer available"
        )
    await session.refresh(job)

    offer.response = OfferResponse.accepted
    offer.responded_at = datetime.now(UTC)

    driver_profile = await session.scalar(
        select(DriverProfile).where(DriverProfile.user_id == user.id)
    )
    if driver_profile is not None:
        driver_profile.status = DriverStatus.on_job
    truck = await session.scalar(select(Truck).where(Truck.driver_id == user.id))
    if truck is not None:
        await dispatch.remove_driver_from_geo(redis, user.id, truck.capacity)

    job = await transition(session, job, JobStatus.assigned, actor=user, event_hook=event_hook)
    return await _job_read(session, job)


@router.post("/{job_id}/reject", response_model=JobRead)
async def reject_job(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
    offer_notifier: OfferNotifierDep,
) -> JobRead:
    """DSP-3: the offered driver declines — DSP-2 advances to the next candidate."""
    job = await _get_job_or_404(session, job_id)
    await _get_pending_offer_or_403(session, job.id, user.id)
    await dispatch.advance_dispatch(
        session,
        redis,
        job,
        driver_id=user.id,
        response=OfferResponse.rejected,
        event_hook=event_hook,
        offer_notifier=offer_notifier,
    )
    await session.refresh(job)
    return await _job_read(session, job)


@router.post("/{job_id}/retry", response_model=JobRead)
async def retry_job(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
    event_hook: EventHookDep,
    offer_notifier: OfferNotifierDep,
) -> JobRead:
    """DSP-5: the customer retries a `no_drivers` job — a fresh matching round."""
    job = await _get_job_or_404(session, job_id)
    if job.customer_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Only the job's customer may retry it"
        )
    if job.status is not JobStatus.no_drivers:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot retry a job in status {job.status.value}",
        )
    await dispatch.retry_dispatch(session, redis, job, event_hook, offer_notifier)
    await session.refresh(job)
    return await _job_read(session, job)


@router.post("/{job_id}/status", response_model=JobRead)
async def update_job_status(
    job_id: uuid.UUID,
    body: JobStatusUpdate,
    user: CurrentUser,
    session: SessionDep,
    event_hook: EventHookDep,
) -> JobRead:
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
        job = await transition(
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
    return await _job_read(session, job)


@router.post("/{job_id}/confirm-delivery", response_model=JobRead)
async def confirm_delivery_endpoint(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
    event_hook: EventHookDep,
) -> JobRead:
    """CUS-5/LED-1: customer confirms delivery + cash payment -> completed + accrual."""
    job = await _get_job_or_404(session, job_id)
    try:
        job = await confirm_delivery(session, job, actor=user, event_hook=event_hook)
    except JobAccessError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except JobTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return await _job_read(session, job)


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
    ended_at = job.completed_at or job.cancelled_at
    if ended_at is not None and datetime.now(UTC) - _as_aware(ended_at) > timedelta(hours=24):
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
