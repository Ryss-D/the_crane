"""Ratings model (RAT-1): each side of a completed job may rate the other once.

Customer rates the driver, driver rates the customer — `to_user_id` is inferred from
the job by the service layer (app/services/ratings.py), never taken from the request.
The unique constraint on (job_id, from_user_id) is the DB-level backstop for "one
rating per side per job"; the service layer checks first for a friendly 409.
"""

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Rating(Base):
    __tablename__ = "ratings"
    __table_args__ = (
        UniqueConstraint("job_id", "from_user_id", name="uq_ratings_job_id_from_user_id"),
        CheckConstraint("stars >= 1 AND stars <= 5", name="ck_ratings_stars_range"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    job_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("jobs.id"), index=True)
    from_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    to_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    stars: Mapped[int] = mapped_column()
    comment: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
