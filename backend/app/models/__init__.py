"""SQLAlchemy models. Import every model here so Alembic sees the full metadata."""

from app.models.base import Base
from app.models.driver import DriverProfile, DriverStatus, Truck, TruckCapacity, TruckType
from app.models.fleet import Fleet
from app.models.job import (
    CustomerVehicle,
    DriverLocationSnapshot,
    Job,
    JobOffer,
    JobStatus,
    OfferResponse,
    PaymentMethod,
    VehicleType,
)
from app.models.ledger import (
    DriverLedgerEntry,
    LedgerEntryType,
    Payment,
    PaymentEvent,
    PaymentProvider,
    PaymentStatus,
    Payout,
    PayoutStatus,
)
from app.models.platform_config import PlatformConfig, PlatformConfigAudit
from app.models.rating import Rating
from app.models.user import User, UserRole

__all__ = [
    "Base",
    "CustomerVehicle",
    "DriverLedgerEntry",
    "DriverLocationSnapshot",
    "DriverProfile",
    "DriverStatus",
    "Fleet",
    "Job",
    "JobOffer",
    "JobStatus",
    "LedgerEntryType",
    "OfferResponse",
    "Payment",
    "PaymentEvent",
    "PaymentMethod",
    "PaymentProvider",
    "PaymentStatus",
    "Payout",
    "PayoutStatus",
    "PlatformConfig",
    "PlatformConfigAudit",
    "Rating",
    "Truck",
    "TruckCapacity",
    "TruckType",
    "User",
    "UserRole",
    "VehicleType",
]
