"""Dispatch / matching service (DSP-1..5): Redis geo index, sequential offers,
radius widening, and the job_offers audit trail.

Geo design (DSP-1): available+verified drivers live in per-capacity Redis geo-sets —
``drivers:geo:moto`` and ``drivers:geo:car`` (GEOADD/GEOSEARCH/ZREM, member = the
driver's user_id as a string). A `both`-capacity driver is written into BOTH sets so
they're reachable for either job type. A `moto` job searches `drivers:geo:moto`; a
`car`/`suv` job searches `drivers:geo:car`. Going offline (or winning a job, DSP-3)
removes the driver from every bucket their truck capacity touches.

Offer design (DSP-2): a job has at most one *pending* job_offers row at a time (the
"active" offer). ``_offer_next`` looks up available+verified candidates ordered by
distance, excluding whichever driver set the caller passes in, creates the next
pending offer, mirrors it into Redis (``dispatch:offer:{job_id}`` -> driver_id, TTL =
``dispatch.offer_ttl_seconds``) as a hint for other consumers (WS/FCM land with
TRK-3 — this service never reads that key back, the DB is the source of truth), and
calls the injectable ``offer_notifier``. If the base-radius search comes up empty it
retries once at ``radius_widen_factor x`` the radius before giving up and moving the
job to `no_drivers` (DSP-5) through the shared state machine (``jobs.transition``).

``start_dispatch`` (initial offer, and DSP-2's re-dispatch after a driver cancels)
excludes every driver who has EVER had a job_offers row for this job — re-offering
someone who already saw this exact job within the same matching episode doesn't make
sense. ``retry_dispatch`` (DSP-5, customer retry from `no_drivers`) is different: it
only excludes drivers who *rejected* within the configured cooldown window, so the
candidate pool refills as that cooldown lapses.
"""

import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver import DriverProfile, DriverStatus, TruckCapacity
from app.models.job import Job, JobOffer, JobStatus, OfferResponse, VehicleType
from app.services.config import RedisLike, get_config
from app.services.jobs import JobEventHook, transition

# Fallbacks when the `dispatch` platform_config key (or one of its fields) is
# missing — mirrors jobs.py's DEFAULT_CANCEL_GRACE_SECONDS pattern.
DEFAULT_OFFER_TTL_SECONDS = 30
DEFAULT_SEARCH_RADIUS_KM = 10.0
DEFAULT_RADIUS_WIDEN_FACTOR = 2
DEFAULT_REJECTION_COOLDOWN_MINUTES = 10

OfferNotifier = Callable[[JobOffer, Job], Awaitable[None]]


async def _noop_offer_notifier(offer: JobOffer, job: Job) -> None:
    return None


def get_offer_notifier() -> OfferNotifier:
    """Dependency returning the offer notifier.

    TRK-3 overrides this to push the offer over FCM + WebSocket to the candidate
    driver; until then offers are recorded but silent (poll-only).
    """
    return _noop_offer_notifier


class GeoRedisLike(RedisLike, Protocol):
    """The Redis geo commands dispatch needs, on top of RedisLike's get/set/delete.

    Matches redis.asyncio.Redis's GEOADD/GEOSEARCH/ZREM signatures directly, so
    production code is unchanged versus the FakeRedis emulation tests use.
    """

    async def geoadd(self, name: str, values: list) -> object: ...
    async def geosearch(self, name: str, **kwargs: object) -> list: ...
    async def zrem(self, name: str, *values: str) -> object: ...


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _as_aware(dt: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC (all stamps are UTC)."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


def _geo_key(bucket: str) -> str:
    return f"drivers:geo:{bucket}"


def _active_offer_key(job_id: uuid.UUID) -> str:
    return f"dispatch:offer:{job_id}"


def _buckets_for_capacity(capacity: TruckCapacity) -> list[str]:
    if capacity is TruckCapacity.both:
        return ["moto", "car"]
    return [capacity.value]


def _capacity_bucket(vehicle_type: VehicleType) -> str:
    """Which geo bucket a job's vehicle_type searches: moto has its own; car/suv share `car`."""
    return "moto" if vehicle_type is VehicleType.moto else "car"


async def add_driver_to_geo(
    redis: GeoRedisLike, driver_id: uuid.UUID, capacity: TruckCapacity, lat: float, lng: float
) -> None:
    """DSP-1: write the driver into every geo bucket their truck capacity covers."""
    for bucket in _buckets_for_capacity(capacity):
        await redis.geoadd(_geo_key(bucket), [lng, lat, str(driver_id)])


async def remove_driver_from_geo(
    redis: GeoRedisLike, driver_id: uuid.UUID, capacity: TruckCapacity
) -> None:
    """DSP-1/DSP-3: drop the driver from every geo bucket (going offline or winning a job)."""
    for bucket in _buckets_for_capacity(capacity):
        await redis.zrem(_geo_key(bucket), str(driver_id))


async def _all_offered_driver_ids(session: AsyncSession, job_id: uuid.UUID) -> set[uuid.UUID]:
    rows = (
        await session.scalars(select(JobOffer.driver_id).where(JobOffer.job_id == job_id))
    ).all()
    return set(rows)


async def _recently_rejected_driver_ids(
    session: AsyncSession, job_id: uuid.UUID, cooldown_minutes: float
) -> set[uuid.UUID]:
    """DSP-5: drivers whose most recent response to this job was a rejection within
    the cooldown window (responded_at is compared in Python — see _as_aware)."""
    cutoff = _utcnow() - timedelta(minutes=cooldown_minutes)
    offers = (
        await session.scalars(
            select(JobOffer).where(
                JobOffer.job_id == job_id,
                JobOffer.response == OfferResponse.rejected,
                JobOffer.responded_at.is_not(None),
            )
        )
    ).all()
    return {o.driver_id for o in offers if _as_aware(o.responded_at) >= cutoff}


async def _search_available_drivers(
    session: AsyncSession,
    redis: GeoRedisLike,
    job: Job,
    radius_km: float,
    excluded: set[uuid.UUID],
) -> list[uuid.UUID]:
    """Nearest available+verified drivers whose capacity fits the job, distance-ordered.

    The geo-set only ever holds drivers who *were* available when they last set
    their status (DSP-1), but a driver could have been unverified since, or another
    concurrent offer could have flipped them to on_job — re-check both against the
    DB before offering.
    """
    bucket = _capacity_bucket(job.vehicle_type)
    members = await redis.geosearch(
        _geo_key(bucket),
        longitude=job.pickup_lng,
        latitude=job.pickup_lat,
        radius=radius_km,
        unit="km",
        sort="ASC",
    )
    ordered_ids = [d for m in members if (d := uuid.UUID(m)) not in excluded]
    if not ordered_ids:
        return []
    eligible = set(
        (
            await session.scalars(
                select(DriverProfile.user_id).where(
                    DriverProfile.user_id.in_(ordered_ids),
                    DriverProfile.verified.is_(True),
                    DriverProfile.status == DriverStatus.available,
                )
            )
        ).all()
    )
    return [d for d in ordered_ids if d in eligible]


async def _offer_next(
    session: AsyncSession,
    redis: GeoRedisLike,
    job: Job,
    event_hook: JobEventHook,
    offer_notifier: OfferNotifier,
    *,
    excluded: set[uuid.UUID],
) -> JobOffer | None:
    """Offer the nearest eligible candidate outside `excluded`; widen once; else no_drivers."""
    dispatch_config = await get_config(session, redis, "dispatch") or {}
    radius_km = dispatch_config.get("search_radius_km", DEFAULT_SEARCH_RADIUS_KM)
    widen_factor = dispatch_config.get("radius_widen_factor", DEFAULT_RADIUS_WIDEN_FACTOR)
    ttl_seconds = dispatch_config.get("offer_ttl_seconds", DEFAULT_OFFER_TTL_SECONDS)

    candidates = await _search_available_drivers(session, redis, job, radius_km, excluded)
    if not candidates:
        candidates = await _search_available_drivers(
            session, redis, job, radius_km * widen_factor, excluded
        )
    if not candidates:
        await redis.delete(_active_offer_key(job.id))
        await transition(session, job, JobStatus.no_drivers, event_hook=event_hook)
        return None

    offer = JobOffer(job_id=job.id, driver_id=candidates[0], response=OfferResponse.pending)
    session.add(offer)
    await session.commit()
    await session.refresh(offer)
    await redis.set(_active_offer_key(job.id), str(offer.driver_id), ex=ttl_seconds)
    await offer_notifier(offer, job)
    return offer


async def start_dispatch(
    session: AsyncSession,
    redis: GeoRedisLike,
    job: Job,
    event_hook: JobEventHook,
    offer_notifier: OfferNotifier | None = None,
) -> JobOffer | None:
    """DSP-2: the initial offer round for a `matching` job.

    Also doubles as the driver-cancel re-dispatch (app/api/jobs.py's cancel
    endpoint): the driver who just bailed already has a job_offers row (their
    `accepted` one), so the "exclude everyone already offered" rule here keeps them
    out for free without any special-casing.
    """
    excluded = await _all_offered_driver_ids(session, job.id)
    return await _offer_next(
        session, redis, job, event_hook, offer_notifier or _noop_offer_notifier, excluded=excluded
    )


async def advance_dispatch(
    session: AsyncSession,
    redis: GeoRedisLike,
    job: Job,
    *,
    driver_id: uuid.UUID | None,
    response: OfferResponse,
    event_hook: JobEventHook,
    offer_notifier: OfferNotifier | None = None,
) -> JobOffer | None:
    """DSP-2/DSP-4: resolve the job's current pending offer (reject/timeout), then
    offer the next nearest candidate (widen/no_drivers per _offer_next).

    `driver_id` scopes which pending offer to resolve (defensive — a job only ever
    has one pending offer at a time, but the sweep passes it explicitly since it's
    iterating over specific stale rows).
    """
    stmt = select(JobOffer).where(
        JobOffer.job_id == job.id, JobOffer.response == OfferResponse.pending
    )
    if driver_id is not None:
        stmt = stmt.where(JobOffer.driver_id == driver_id)
    offer = await session.scalar(stmt)
    if offer is not None:
        offer.response = response
        offer.responded_at = _utcnow()
        await session.commit()

    if job.status is not JobStatus.matching:
        # Already resolved some other way (accept race, cancel, ...) — nothing to advance.
        return None

    excluded = await _all_offered_driver_ids(session, job.id)
    return await _offer_next(
        session, redis, job, event_hook, offer_notifier or _noop_offer_notifier, excluded=excluded
    )


async def retry_dispatch(
    session: AsyncSession,
    redis: GeoRedisLike,
    job: Job,
    event_hook: JobEventHook,
    offer_notifier: OfferNotifier | None = None,
) -> JobOffer | None:
    """DSP-5: customer retry from `no_drivers` -> a fresh matching round.

    Unlike start_dispatch, only drivers who *rejected* within
    dispatch.rejection_cooldown_minutes are excluded — the point of retry is to
    refill the candidate pool, not repeat the exact same search that just failed.
    """
    dispatch_config = await get_config(session, redis, "dispatch") or {}
    cooldown_minutes = dispatch_config.get(
        "rejection_cooldown_minutes", DEFAULT_REJECTION_COOLDOWN_MINUTES
    )
    excluded = await _recently_rejected_driver_ids(session, job.id, cooldown_minutes)
    job = await transition(session, job, JobStatus.matching, event_hook=event_hook)
    return await _offer_next(
        session, redis, job, event_hook, offer_notifier or _noop_offer_notifier, excluded=excluded
    )
