"""DSP-4: background sweep that expires stale pending offers and advances dispatch.

The DB is the source of truth: a pending job_offers row older than
``dispatch.offer_ttl_seconds`` is stale regardless of what Redis thinks — the
``dispatch:offer:{job_id}`` key dispatch.py sets is only a TTL *hint* for other
consumers (e.g. a future WS push); this sweep never reads it. That makes the sweep
safe across restarts: a fresh process just re-scans job_offers from scratch, no
in-memory state to lose.

``sweep_expired_offers`` is a single deterministic pass — used directly by tests and
by the loop below. ``run_offer_expiry_worker`` wraps it in an asyncio loop, started
from the app lifespan (app/main.py) only when ``settings.enable_workers`` is true,
and cleanly cancelled on shutdown.
"""

import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.job import Job, JobOffer, JobStatus, OfferResponse
from app.services.config import RedisLike, get_config
from app.services.dispatch import DEFAULT_OFFER_TTL_SECONDS, advance_dispatch
from app.services.jobs import get_job_event_hook

logger = logging.getLogger(__name__)

# Floor for the sweep loop's own cadence, independent of how short the configured
# offer TTL is (DSP-4: interval = max(5, ttl / 6) seconds).
MIN_SWEEP_INTERVAL_SECONDS = 5


def _as_aware(dt: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC (all stamps are UTC)."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


async def sweep_expired_offers(
    session_factory: async_sessionmaker[AsyncSession], redis: RedisLike
) -> int:
    """One sweep pass: expire pending offers past TTL, advance each job's dispatch.

    Returns the number of offers expired (used by tests / logging).
    """
    async with session_factory() as session:
        dispatch_config = await get_config(session, redis, "dispatch") or {}
        ttl_seconds = dispatch_config.get("offer_ttl_seconds", DEFAULT_OFFER_TTL_SECONDS)
        now = datetime.now(UTC)

        pending = (
            await session.scalars(
                select(JobOffer).where(JobOffer.response == OfferResponse.pending)
            )
        ).all()

        expired = 0
        for offer in pending:
            if (now - _as_aware(offer.offered_at)).total_seconds() < ttl_seconds:
                continue
            job = await session.get(Job, offer.job_id)
            if job is None or job.status is not JobStatus.matching:
                continue
            await advance_dispatch(
                session,
                redis,
                job,
                driver_id=offer.driver_id,
                response=OfferResponse.timeout,
                event_hook=get_job_event_hook(),
            )
            expired += 1
        return expired


async def run_offer_expiry_worker(
    session_factory: async_sessionmaker[AsyncSession], redis: RedisLike
) -> None:
    """Loop sweep_expired_offers until cancelled; interval self-adjusts to the TTL."""
    while True:
        interval = float(MIN_SWEEP_INTERVAL_SECONDS)
        try:
            async with session_factory() as session:
                dispatch_config = await get_config(session, redis, "dispatch") or {}
            ttl_seconds = dispatch_config.get("offer_ttl_seconds", DEFAULT_OFFER_TTL_SECONDS)
            interval = max(MIN_SWEEP_INTERVAL_SECONDS, ttl_seconds / 6)
            await sweep_expired_offers(session_factory, redis)
        except asyncio.CancelledError:
            raise
        except Exception:
            # A bad sweep pass shouldn't kill the worker — log and try again next tick.
            logger.exception("offer expiry sweep failed")
        await asyncio.sleep(interval)
