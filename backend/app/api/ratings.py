"""Ratings API (RAT-1): POST/GET under /v1/jobs/{id}/rating(s).

Kept as its own router rather than folded into app/api/jobs.py — the rating
lifecycle (access/state/duplicate checks + rating_avg recompute) is fully owned
by app/services/ratings.py and only needs the job's row, none of jobs.py's
dispatch/pricing/event-hook wiring. Mounted at the same /v1/jobs prefix in
app/main.py so the routes still read as job sub-resources.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import CurrentUser
from app.models.job import Job
from app.models.rating import Rating
from app.models.user import UserRole
from app.schemas.rating import JobRatingsResponse, RatingCreate, RatingRead
from app.services.ratings import (
    RatingAccessError,
    RatingDuplicateError,
    RatingStateError,
    create_rating,
    get_job_ratings,
)

router = APIRouter(prefix="/jobs", tags=["ratings"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def _get_job_or_404(session: AsyncSession, job_id: uuid.UUID) -> Job:
    job = await session.get(Job, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    return job


@router.post("/{job_id}/rating", response_model=RatingRead, status_code=status.HTTP_201_CREATED)
async def rate_job(
    job_id: uuid.UUID,
    body: RatingCreate,
    user: CurrentUser,
    session: SessionDep,
) -> Rating:
    """Only the job's customer or assigned driver may rate, only once each, only
    after the job is `completed`. `to_user_id` is inferred, not accepted here."""
    job = await _get_job_or_404(session, job_id)
    try:
        return await create_rating(session, job, actor=user, stars=body.stars, comment=body.comment)
    except RatingAccessError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except (RatingStateError, RatingDuplicateError) as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.get("/{job_id}/ratings", response_model=JobRatingsResponse)
async def list_job_ratings(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: SessionDep,
) -> JobRatingsResponse:
    """Visible only to the job's customer/driver/admin."""
    job = await _get_job_or_404(session, job_id)
    if user.role is not UserRole.admin and user.id not in (job.customer_id, job.driver_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this job's ratings",
        )
    ratings = await get_job_ratings(session, job_id)
    return JobRatingsResponse(items=ratings)
