"""Round-trip the new JOB-1/LED-1 models through a sqlite session (metadata-created)."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models import (
    CustomerVehicle,
    DriverLedgerEntry,
    DriverLocationSnapshot,
    DriverProfile,
    DriverStatus,
    Fleet,
    Job,
    JobOffer,
    JobStatus,
    LedgerEntryType,
    OfferResponse,
    Payment,
    PaymentEvent,
    PaymentMethod,
    PaymentProvider,
    PaymentStatus,
    Payout,
    PayoutStatus,
    Truck,
    TruckCapacity,
    TruckType,
    User,
    UserRole,
    VehicleType,
)


async def _add_user(session: AsyncSession, role: UserRole) -> User:
    user = User(firebase_uid=f"uid-{uuid.uuid4()}", role=role, name="U", phone="+57300")
    session.add(user)
    await session.flush()
    return user


async def test_driver_profile_and_truck_roundtrip(
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    async with session_maker() as session:
        driver = await _add_user(session, UserRole.driver)
        session.add(
            DriverProfile(user_id=driver.id, rating_avg=Decimal("4.75"), license_url="http://l")
        )
        session.add(
            Truck(
                plate="ABC123",
                type=TruckType.flatbed,
                capacity=TruckCapacity.both,
                driver_id=driver.id,
            )
        )
        await session.commit()

        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == driver.id)
        )
        assert profile is not None
        assert profile.status is DriverStatus.offline  # default
        assert profile.verified is False
        assert profile.rating_avg == Decimal("4.75")

        truck = await session.scalar(select(Truck).where(Truck.plate == "ABC123"))
        assert truck is not None
        assert truck.type is TruckType.flatbed
        assert truck.capacity is TruckCapacity.both
        assert truck.fleet_id is None


async def test_fleet_roundtrip_and_truck_fk(
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    async with session_maker() as session:
        owner = await _add_user(session, UserRole.fleet_owner)
        driver = await _add_user(session, UserRole.driver)
        fleet = Fleet(owner_user_id=owner.id, name="Grúas del Poblado")
        session.add(fleet)
        await session.flush()
        session.add(
            Truck(
                plate="FLT001",
                type=TruckType.car,
                capacity=TruckCapacity.car,
                driver_id=driver.id,
                fleet_id=fleet.id,
            )
        )
        await session.commit()

        loaded = await session.scalar(select(Fleet).where(Fleet.owner_user_id == owner.id))
        assert loaded is not None
        assert loaded.name == "Grúas del Poblado"
        assert loaded.created_at is not None

        truck = await session.scalar(select(Truck).where(Truck.plate == "FLT001"))
        assert truck is not None
        assert truck.fleet_id == fleet.id


async def test_job_offer_and_snapshot_roundtrip(
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    async with session_maker() as session:
        customer = await _add_user(session, UserRole.customer)
        driver = await _add_user(session, UserRole.driver)
        session.add(CustomerVehicle(user_id=customer.id, type=VehicleType.moto, plate="XYZ98"))
        job = Job(
            customer_id=customer.id,
            vehicle_type=VehicleType.car,
            pickup_lat=6.2442,
            pickup_lng=-75.5812,
            dropoff_lat=6.1701,
            dropoff_lng=-75.6058,
            pickup_address="Cl 10 # 43-12, Medellín",
            dropoff_address="Cra 48 # 20-114, Medellín",
            distance_km=Decimal("12.40"),
            quoted_price=Decimal("122000"),
            config_snapshot={"pricing": {"car": {"base": 60000}}},
        )
        session.add(job)
        await session.flush()
        session.add(JobOffer(job_id=job.id, driver_id=driver.id))
        session.add(
            DriverLocationSnapshot(
                job_id=job.id,
                driver_id=driver.id,
                lat=6.24,
                lng=-75.58,
                job_status=JobStatus.assigned,
            )
        )
        await session.commit()

        loaded = await session.scalar(select(Job).where(Job.id == job.id))
        assert loaded is not None
        assert loaded.status is JobStatus.requested  # default
        assert loaded.payment_method is PaymentMethod.cash  # default
        assert loaded.driver_id is None
        assert loaded.quoted_price == Decimal("122000")
        assert loaded.config_snapshot == {"pricing": {"car": {"base": 60000}}}
        assert isinstance(loaded.share_token, uuid.UUID)
        assert loaded.requested_at is not None

        offer = await session.scalar(select(JobOffer).where(JobOffer.job_id == job.id))
        assert offer is not None
        assert offer.response is OfferResponse.pending  # default
        assert offer.responded_at is None

        snap = await session.scalar(
            select(DriverLocationSnapshot).where(DriverLocationSnapshot.job_id == job.id)
        )
        assert snap is not None
        assert snap.job_status is JobStatus.assigned


async def test_ledger_tables_roundtrip(session_maker: async_sessionmaker[AsyncSession]) -> None:
    async with session_maker() as session:
        customer = await _add_user(session, UserRole.customer)
        driver = await _add_user(session, UserRole.driver)
        job = Job(
            customer_id=customer.id,
            driver_id=driver.id,
            vehicle_type=VehicleType.suv,
            pickup_lat=1.0,
            pickup_lng=2.0,
            dropoff_lat=3.0,
            dropoff_lng=4.0,
            pickup_address="A",
            dropoff_address="B",
        )
        session.add(job)
        await session.flush()

        payment = Payment(
            job_id=job.id,
            provider=PaymentProvider.cash,
            reference=f"ref-{uuid.uuid4()}",
            amount=Decimal("90000"),
            method=PaymentMethod.cash,
        )
        session.add(payment)
        await session.flush()
        session.add(
            PaymentEvent(
                payment_id=payment.id, dedup_key="evt-1:created", payload={"event": "created"}
            )
        )

        payout = Payout(
            driver_id=driver.id,
            amount=Decimal("13500"),
            period_start=datetime(2026, 8, 1, tzinfo=UTC),
            period_end=datetime(2026, 8, 7, tzinfo=UTC),
        )
        session.add(payout)
        await session.flush()
        session.add(
            DriverLedgerEntry(
                driver_id=driver.id,
                job_id=job.id,
                gross=Decimal("90000"),
                commission=Decimal("13500"),
                net=Decimal("76500"),
                entry_type=LedgerEntryType.earning,
                payout_id=payout.id,
            )
        )
        await session.commit()

        loaded_payment = await session.scalar(select(Payment).where(Payment.id == payment.id))
        assert loaded_payment is not None
        assert loaded_payment.status is PaymentStatus.pending  # default
        assert loaded_payment.currency == "COP"  # default
        assert loaded_payment.amount == Decimal("90000")

        loaded_payout = await session.scalar(select(Payout).where(Payout.id == payout.id))
        assert loaded_payout is not None
        assert loaded_payout.status is PayoutStatus.pending  # default

        entry = await session.scalar(
            select(DriverLedgerEntry).where(DriverLedgerEntry.driver_id == driver.id)
        )
        assert entry is not None
        assert entry.entry_type is LedgerEntryType.earning
        assert entry.net == Decimal("76500")
        assert entry.payout_id == payout.id
