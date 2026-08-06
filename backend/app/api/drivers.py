"""Drivers router: AUTH-5 registration + DSP-1 status/geo.

DSP-3's accept/reject and DSP-5's retry are job-lifecycle actions and live in
app/api/jobs.py instead, next to cancel/status/confirm-delivery which already own
the "actor may act on this job" permission patterns and the job_offers/dispatch
service wiring. This router stays driver-profile-centric (registration, own status).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import CurrentUser
from app.models.driver import DriverProfile, DriverStatus, Truck
from app.models.user import UserRole
from app.schemas.driver import (
    DriverProfileRead,
    DriverRegisterRequest,
    DriverStatusUpdate,
    TruckRead,
)
from app.services import dispatch
from app.services.config import RedisLike, get_config
from app.services.ledger import driver_owed_balance, fleet_owed_balance

router = APIRouter(prefix="/drivers", tags=["drivers"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]
RedisDep = Annotated[RedisLike, Depends(get_redis)]


async def _get_profile_or_404(session: AsyncSession, user_id) -> DriverProfile:
    profile = await session.scalar(select(DriverProfile).where(DriverProfile.user_id == user_id))
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver profile not found — register first (POST /v1/drivers/me/register)",
        )
    return profile


async def _get_truck(session: AsyncSession, driver_id) -> Truck | None:
    return await session.scalar(select(Truck).where(Truck.driver_id == driver_id))


async def _serialize_profile(session: AsyncSession, profile: DriverProfile) -> DriverProfileRead:
    truck = await _get_truck(session, profile.user_id)
    return DriverProfileRead(
        id=profile.id,
        user_id=profile.user_id,
        status=profile.status,
        verified=profile.verified,
        license_url=profile.license_url,
        truck_photo_url=profile.truck_photo_url,
        rating_avg=float(profile.rating_avg) if profile.rating_avg is not None else None,
        truck=TruckRead.model_validate(truck) if truck is not None else None,
    )


@router.post("/me/register", response_model=DriverProfileRead, status_code=status.HTTP_201_CREATED)
async def register_driver(
    body: DriverRegisterRequest,
    user: CurrentUser,
    session: SessionDep,
) -> DriverProfileRead:
    """AUTH-5: create driver_profiles (unverified, offline) + trucks, flip role -> driver.

    409 if the caller is already a driver. Document upload is out of scope (see the
    schema docstring); license_url/truck_photo_url are accepted as-is.
    """
    existing = await session.scalar(select(DriverProfile).where(DriverProfile.user_id == user.id))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Already registered as a driver"
        )

    profile = DriverProfile(
        user_id=user.id,
        status=DriverStatus.offline,
        verified=False,
        license_url=body.license_url,
        truck_photo_url=body.truck_photo_url,
    )
    truck = Truck(
        plate=body.plate,
        type=body.truck_type,
        capacity=body.capacity,
        driver_id=user.id,
    )
    user.role = UserRole.driver
    session.add_all([profile, truck])
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Plate already registered"
        ) from exc
    await session.refresh(profile)
    return await _serialize_profile(session, profile)


@router.patch("/me/status", response_model=DriverProfileRead)
async def update_driver_status(
    body: DriverStatusUpdate,
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
) -> DriverProfileRead:
    """DSP-1: flip available/offline and mirror membership into the Redis geo index.

    403 unverified, 403 blocked (ADM-2 admin hold — an admin must unblock first),
    409 on_job (mid-job — status is driven by the job lifecycle instead), 422 if
    going available without lat/lng, 403 if the driver's owed balance is at or over
    settlement.balance_cap (same "not allowed to work" class as unverified, so it
    shares the 403).
    """
    if body.status not in (DriverStatus.available, DriverStatus.offline):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="status must be 'available' or 'offline'",
        )
    profile = await _get_profile_or_404(session, user.id)
    if not profile.verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Driver is not verified yet"
        )
    if profile.status is DriverStatus.blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Driver is blocked — contact an admin to unblock",
        )
    if profile.status is DriverStatus.on_job:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Cannot change status while on a job"
        )
    truck = await _get_truck(session, user.id)
    if truck is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="No truck registered for this driver"
        )

    if body.status is DriverStatus.available:
        if body.lat is None or body.lng is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="lat/lng are required to go available",
            )
        settlement_config = await get_config(session, redis, "settlement") or {}
        balance_cap = settlement_config.get("balance_cap")
        if balance_cap is not None:
            # FLT-2: a driver riding a fleet's truck is gated on the fleet's
            # consolidated balance, not just their own — one fleet settlement
            # (POST /v1/admin/fleets/{id}/settle) is what unblocks every capped
            # member together, matching the fleet's own settle-once story.
            owed = (
                await fleet_owed_balance(session, truck.fleet_id)
                if truck.fleet_id is not None
                else await driver_owed_balance(session, user.id)
            )
            if owed >= balance_cap:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Balance owed to the platform exceeds the allowed cap",
                )
        await dispatch.add_driver_to_geo(redis, user.id, truck.capacity, body.lat, body.lng)
        profile.status = DriverStatus.available
    else:
        await dispatch.remove_driver_from_geo(redis, user.id, truck.capacity)
        profile.status = DriverStatus.offline

    await session.commit()
    await session.refresh(profile)
    return await _serialize_profile(session, profile)
