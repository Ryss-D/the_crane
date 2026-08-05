"""Ratings service (RAT-1): infer the rated side from the job, enforce one rating
per side after completion, and keep driver_profiles.rating_avg in sync.

`to_user_id` is always derived here from the job, never accepted from the request
(see app/models/rating.py's docstring) — the customer rates the assigned driver,
the driver rates the customer.
"""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver import DriverProfile
from app.models.job import Job, JobStatus
from app.models.rating import Rating
from app.models.user import User


class RatingAccessError(Exception):
    """Actor is neither the job's customer nor its assigned driver — 403 at the API layer."""


class RatingStateError(Exception):
    """Job isn't completed yet (or has no assigned driver) — 409 at the API layer."""


class RatingDuplicateError(Exception):
    """This side already rated the job — 409 at the API layer (friendly, not a raw
    IntegrityError bubbling up from the DB's unique constraint)."""


def _resolve_to_user_id(job: Job, actor: User) -> uuid.UUID | None:
    """The user `actor` is rating, or None if the job has no assigned driver yet."""
    if actor.id == job.customer_id:
        return job.driver_id
    if job.driver_id is not None and actor.id == job.driver_id:
        return job.customer_id
    raise RatingAccessError("Only the job's customer or assigned driver may rate it")


async def create_rating(
    session: AsyncSession,
    job: Job,
    *,
    actor: User,
    stars: int,
    comment: str | None,
) -> Rating:
    """Insert `actor`'s rating of the other side of `job`.

    Order of checks matches the API contract: wrong actor -> 403 regardless of job
    status; right actor but job not completed -> 409; already rated -> 409. On a
    driver-directed rating, recomputes driver_profiles.rating_avg as the simple mean
    over all ratings the driver has received.
    """
    to_user_id = _resolve_to_user_id(job, actor)
    if job.status is not JobStatus.completed:
        raise RatingStateError("Job must be completed before it can be rated")
    if to_user_id is None:
        # Defensive: a completed job always has a driver assigned; guards a corrupt state.
        raise RatingStateError("Job has no assigned driver to rate")

    existing = await session.scalar(
        select(Rating).where(Rating.job_id == job.id, Rating.from_user_id == actor.id)
    )
    if existing is not None:
        raise RatingDuplicateError("You have already rated this job")

    rating = Rating(
        job_id=job.id,
        from_user_id=actor.id,
        to_user_id=to_user_id,
        stars=stars,
        comment=comment,
    )
    session.add(rating)

    if to_user_id == job.driver_id:
        await session.flush()  # make the new row visible to the avg query below
        avg = await session.scalar(
            select(func.avg(Rating.stars)).where(Rating.to_user_id == job.driver_id)
        )
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == job.driver_id)
        )
        if profile is not None and avg is not None:
            profile.rating_avg = round(float(avg), 2)

    await session.commit()
    await session.refresh(rating)
    return rating


async def get_job_ratings(session: AsyncSession, job_id: uuid.UUID) -> list[Rating]:
    """Both ratings for a job (whichever sides have rated so far), oldest first."""
    return list(
        (
            await session.scalars(
                select(Rating).where(Rating.job_id == job_id).order_by(Rating.created_at)
            )
        ).all()
    )
