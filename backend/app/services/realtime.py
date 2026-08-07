"""Real implementations of the injectable job-event hook (services/jobs.py) and offer
notifier (services/dispatch.py) — TRK-3. Wired as the production dependency overrides
in app/main.py; the no-op defaults in jobs.py/dispatch.py only apply where tests
explicitly override them back (mirrors every other injectable in this codebase).

Job transitions broadcast on two Redis channels via the connection manager:
  - the full `job_event` (status, driver_id, price, timestamps) to the job's
    authenticated subscribers (its customer + assigned driver);
  - a reduced `job_event` (status + driver first name/plate only — same fields
    GET /v1/track/{token} already exposes) to the job's public share-token viewers,
    so the WS path never leaks more than the poll endpoint does (TRK-6).
Alongside the WS broadcast, a data-only FCM push (app/services/push.py) goes to the
customer's and (if assigned) driver's `fcm_token` — the case that covers an
app-killed/backgrounded client WS can never reach, including a driver learning their
assigned job was cancelled or reassigned.

Offers push a `job_offer` message straight to the offered driver's live WS
connections, if any, plus the same FCM push to their `fcm_token` — a
backgrounded/disconnected driver now gets one over FCM even when WS misses them.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver import Truck
from app.models.job import Job, JobOffer, JobStatus
from app.models.user import User
from app.schemas.job import (
    DriverLocationEvent,
    JobEventPayload,
    JobOfferEvent,
    JobTrackEvent,
    LatLng,
    TrackDriver,
)
from app.services.config import RedisLike
from app.services.connection_manager import ConnectionManager
from app.services.dispatch import DEFAULT_OFFER_TTL_SECONDS, GeoRedisLike, driver_geo_position
from app.services.jobs import commission_for_fare
from app.services.pricing import haversine_km
from app.services.push import send_push

__all__ = ["broadcast_job_event", "notify_driver_offer", "publish_driver_location"]


async def _push_to_user(session: AsyncSession, user_id, data: dict[str, str]) -> None:
    """Best-effort FCM push to `user_id`'s stored token; a missing user or unset
    `fcm_token` is a silent no-op (send_push itself no-ops on a falsy token too --
    this just avoids the extra lookup when there's nothing to look up)."""
    user = await session.get(User, user_id)
    if user is not None and user.fcm_token:
        await send_push(user.fcm_token, data)


async def _track_driver_block(session: AsyncSession, job: Job) -> TrackDriver | None:
    """Same limited fields as GET /v1/track/{token}: first name + truck plate."""
    if job.driver_id is None:
        return None
    driver_user = await session.get(User, job.driver_id)
    truck = await session.scalar(select(Truck).where(Truck.driver_id == job.driver_id))
    first_name = driver_user.name.split()[0] if driver_user and driver_user.name else None
    return TrackDriver(first_name=first_name, truck_plate=truck.plate if truck else None)


async def broadcast_job_event(
    session: AsyncSession,
    redis: RedisLike,
    manager: ConnectionManager,
    job: Job,
    old_status: JobStatus,
    new_status: JobStatus,
) -> None:
    """TRK-3: the real `get_job_event_hook()` override — called by jobs.transition()
    on every state change, after its commit."""
    full = JobEventPayload(
        job_id=job.id,
        status=new_status,
        old_status=old_status,
        driver_id=job.driver_id,
        quoted_price=job.quoted_price,
        final_price=job.final_price,
        requested_at=job.requested_at,
        assigned_at=job.assigned_at,
        picked_up_at=job.picked_up_at,
        completed_at=job.completed_at,
        cancelled_at=job.cancelled_at,
        cancel_reason=job.cancel_reason,
    )
    await manager.publish_job(redis, job.id, full.model_dump(mode="json"))

    driver = await _track_driver_block(session, job)
    track = JobTrackEvent(job_id=job.id, status=new_status, driver=driver)
    await manager.publish_job_track(redis, job.id, track.model_dump(mode="json"))

    push_data = {"type": "job_event", "job_id": str(job.id), "status": new_status.value}
    await _push_to_user(session, job.customer_id, push_data)
    if job.driver_id is not None:
        await _push_to_user(session, job.driver_id, push_data)


async def notify_driver_offer(
    session: AsyncSession,
    redis: GeoRedisLike,
    manager: ConnectionManager,
    offer: JobOffer,
    job: Job,
) -> None:
    """TRK-3: the real `get_offer_notifier()` override. `session`/`redis`/`manager`
    are bound by app/main.py's `_real_offer_notifier` closure, not by the
    OfferNotifier type itself — that callable still matches dispatch.py's
    `(offer, job) -> Awaitable[None]` shape exactly, so adding the FCM lookup below
    doesn't touch dispatch.py's `_offer_next`/`start_dispatch`/`advance_dispatch`/
    `retry_dispatch` call sites at all.

    Uses the fixed default TTL for the informational countdown field rather than a
    live config lookup (would need a session here just for that) — authoritative
    expiry enforcement stays server-side in POST /v1/jobs/{id}/accept, which checks
    the actual configured `dispatch.offer_ttl_seconds` against `offer.offered_at`.

    DRV-2: pickup_distance_km/commission_amount are best-effort enrichments, not
    load-bearing for dispatch — a missing geo entry (position) or quote
    (commission) just leaves the field None rather than failing the offer.
    """
    position = await driver_geo_position(redis, job.vehicle_type, offer.driver_id)
    pickup_distance_km = (
        round(haversine_km(position, (job.pickup_lat, job.pickup_lng)), 2)
        if position is not None
        else None
    )
    commission_amount = (
        commission_for_fare(job, int(job.quoted_price)) if job.quoted_price is not None else None
    )
    payload = JobOfferEvent(
        job_id=job.id,
        offer_id=offer.id,
        vehicle_type=job.vehicle_type,
        pickup=LatLng(lat=job.pickup_lat, lng=job.pickup_lng),
        dropoff=LatLng(lat=job.dropoff_lat, lng=job.dropoff_lng),
        quoted_price=job.quoted_price,
        expires_in_seconds=DEFAULT_OFFER_TTL_SECONDS,
        pickup_distance_km=pickup_distance_km,
        commission_amount=commission_amount,
    )
    await manager.publish_to_user(redis, offer.driver_id, payload.model_dump(mode="json"))
    await _push_to_user(
        session,
        offer.driver_id,
        {"type": "job_offer", "job_id": str(job.id), "offer_id": str(offer.id)},
    )


async def publish_driver_location(
    redis: RedisLike, manager: ConnectionManager, job_id, lat: float, lng: float
) -> None:
    """TRK-2: relay a driver's WS location message to both the full job channel and
    its public track channel — identical payload either way, no extra PII to filter
    (lat/lng is exactly what the poll endpoint's `driver_location` field exposes)."""
    event = DriverLocationEvent(job_id=job_id, lat=lat, lng=lng).model_dump(mode="json")
    await manager.publish_job(redis, job_id, event)
    await manager.publish_job_track(redis, job_id, event)
