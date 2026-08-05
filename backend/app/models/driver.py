"""Driver-side models: driver_profiles and trucks (AUTH-5 fills the registration flow)."""

import enum
import uuid
from decimal import Decimal

from sqlalchemy import Enum, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class DriverStatus(enum.StrEnum):
    offline = "offline"
    available = "available"
    on_job = "on_job"


class TruckType(enum.StrEnum):
    moto_only = "moto_only"
    flatbed = "flatbed"
    standard = "standard"


class TruckCapacity(enum.StrEnum):
    moto = "moto"
    car = "car"
    both = "both"


class DriverProfile(Base):
    __tablename__ = "driver_profiles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    status: Mapped[DriverStatus] = mapped_column(
        Enum(DriverStatus, name="driver_status", native_enum=False, length=20),
        default=DriverStatus.offline,
    )
    verified: Mapped[bool] = mapped_column(default=False)
    license_url: Mapped[str | None] = mapped_column(String(512))
    truck_photo_url: Mapped[str | None] = mapped_column(String(512))
    rating_avg: Mapped[Decimal | None] = mapped_column(Numeric(3, 2))


class Truck(Base):
    __tablename__ = "trucks"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    plate: Mapped[str] = mapped_column(String(16), unique=True)
    type: Mapped[TruckType] = mapped_column(
        Enum(TruckType, name="truck_type", native_enum=False, length=20)
    )
    capacity: Mapped[TruckCapacity] = mapped_column(
        Enum(TruckCapacity, name="truck_capacity", native_enum=False, length=20)
    )
    driver_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    # No FK yet on purpose: the fleets table arrives in Phase 6 (FLT-1), which adds the FK.
    fleet_id: Mapped[uuid.UUID | None] = mapped_column()
