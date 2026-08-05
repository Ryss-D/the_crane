"""Request/response schemas for ratings (RAT-1)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class RatingCreate(BaseModel):
    """POST /v1/jobs/{id}/rating body — `to_user_id` is inferred server-side from
    the job (customer rates the driver, driver rates the customer), never taken
    from the request."""

    stars: int = Field(ge=1, le=5)
    comment: str | None = None


class RatingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    job_id: uuid.UUID
    from_user_id: uuid.UUID
    to_user_id: uuid.UUID
    stars: int
    comment: str | None
    created_at: datetime


class JobRatingsResponse(BaseModel):
    """GET /v1/jobs/{id}/ratings — both sides' ratings, if given (oldest first)."""

    items: list[RatingRead]
