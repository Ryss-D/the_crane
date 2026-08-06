"""Fleet owner model (FLT-1): a fleet_owner user who owns a group of trucks.

One fleet per owner (unique `owner_user_id`, same convention as driver_profiles'
unique `user_id`). Trucks join a fleet via `trucks.fleet_id` (added ahead of time in
AUTH-5, nullable — a truck can exist with no fleet, and independent drivers keep
working unaffected). This migration (0007) is the one that finally adds the FK from
trucks.fleet_id to this table, per the note left on that column in app/models/driver.py.

FLT-4 (migration 0009) adds `DriverInvite`: a fleet owner pre-provisions a truck for a
driver who doesn't have an account (or a truck) yet, and hands them a token redeemed
by POST /v1/drivers/me/register. It's a dedicated table rather than nullable columns
on Truck because it has its own pending -> consumed lifecycle and needs the invited
phone number, which doesn't belong on Truck itself.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
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


class InviteStatus(enum.StrEnum):
    pending = "pending"
    consumed = "consumed"


class DriverInvite(Base):
    """FLT-4: a fleet owner's phone invite for a truck that's already been created
    (unclaimed -- `driver_id is None`) but has no driver yet. Redeemed by
    `POST /v1/drivers/me/register`'s `invite_token`, which links the caller onto
    `truck_id` instead of creating a new truck, then flips `status` to `consumed`
    so it can't be redeemed twice.
    """

    __tablename__ = "driver_invites"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    fleet_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("fleets.id"), index=True)
    truck_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("trucks.id"), index=True)
    phone: Mapped[str] = mapped_column(String(32), index=True)
    token: Mapped[uuid.UUID] = mapped_column(unique=True, default=uuid.uuid4)
    status: Mapped[InviteStatus] = mapped_column(
        Enum(InviteStatus, name="invite_status", native_enum=False, length=20),
        default=InviteStatus.pending,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
