"""Fleet owner model (FLT-1): a fleet_owner user who owns a group of trucks.

One fleet per owner (unique `owner_user_id`, same convention as driver_profiles'
unique `user_id`). Trucks join a fleet via `trucks.fleet_id` (added ahead of time in
AUTH-5, nullable — a truck can exist with no fleet, and independent drivers keep
working unaffected). This migration (0007) is the one that finally adds the FK from
trucks.fleet_id to this table, per the note left on that column in app/models/driver.py.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Fleet(Base):
    __tablename__ = "fleets"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
