"""Drivers router: AUTH-5 registration + DSP-1 status/geo.

DSP-3's accept/reject and DSP-5's retry are job-lifecycle actions and live in
app/api/jobs.py instead, next to cancel/status/confirm-delivery which already own
the "actor may act on this job" permission patterns and the job_offers/dispatch
service wiring. This router stays driver-profile-centric (registration, own status).
"""

import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import CurrentUser, VerifiedClaims
from app.models.driver import DriverProfile, DriverStatus, Truck
from app.models.fleet import DriverInvite, InviteStatus
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.user import UserRole
from app.schemas.driver import (
    DriverBalanceRead,
    DriverProfileRead,
    DriverRegisterRequest,
    DriverSettlementRead,
    DriverStatusUpdate,
    TruckRead,
)
from app.schemas.payments import DriverSettleRequest, DriverSettleResponse
from app.services import dispatch
from app.services.config import RedisLike, get_config
from app.services.ledger import driver_owed_balance, fleet_owed_balance
from app.services.payments.wompi import WompiApiError, WompiGateway, WompiNotConfiguredError

router = APIRouter(prefix="/drivers", tags=["drivers"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]
RedisDep = Annotated[RedisLike, Depends(get_redis)]

RECENT_SETTLEMENTS_LIMIT = 20


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
    claims: VerifiedClaims,
    session: SessionDep,
) -> DriverProfileRead:
    """AUTH-5: create driver_profiles (unverified, offline) + trucks, flip role -> driver.

    Two mutually exclusive shapes (see DriverRegisterRequest's docstring): bring your
    own truck (`plate`/`truck_type`/`capacity`), or redeem a fleet owner's invite
    (`invite_token`, FLT-4) which already pre-provisioned the truck — mixing the two
    is 422. Redeeming an invite additionally requires the caller's verified Firebase
    phone claim to match the phone the invite was created for (403 otherwise), and
    marks the invite consumed so it can't be redeemed twice (409 if it already was,
    404 if the token doesn't exist).

    409 if the caller is already a driver. Document upload is out of scope (see the
    schema docstring); license_url/truck_photo_url are accepted as-is.
    """
    existing = await session.scalar(select(DriverProfile).where(DriverProfile.user_id == user.id))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Already registered as a driver"
        )

    has_truck_fields = (
        body.plate is not None or body.truck_type is not None or body.capacity is not None
    )

    if body.invite_token is not None:
        if has_truck_fields:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="invite_token and plate/truck_type/capacity are mutually exclusive",
            )
        invite = await session.scalar(
            select(DriverInvite).where(DriverInvite.token == body.invite_token)
        )
        if invite is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found")
        if invite.status is not InviteStatus.pending:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Invite already used")
        if invite.phone != claims.get("phone_number"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invite phone does not match the caller's verified phone number",
            )
        truck = await session.get(Truck, invite.truck_id)
        if truck is None or truck.driver_id is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Invited truck is no longer available"
            )
        truck.driver_id = user.id
        invite.status = InviteStatus.consumed
        invite.consumed_at = datetime.now(UTC)
    else:
        if (
            not has_truck_fields
            or body.plate is None
            or body.truck_type is None
            or body.capacity is None
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="plate, truck_type, and capacity are required without an invite_token",
            )
        truck = Truck(
            plate=body.plate,
            type=body.truck_type,
            capacity=body.capacity,
            driver_id=user.id,
        )
        session.add(truck)

    profile = DriverProfile(
        user_id=user.id,
        status=DriverStatus.offline,
        verified=False,
        license_url=body.license_url,
        truck_photo_url=body.truck_photo_url,
    )
    user.role = UserRole.driver
    session.add(profile)
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


@router.get("/me/balance", response_model=DriverBalanceRead)
async def get_my_balance(
    user: CurrentUser,
    session: SessionDep,
    redis: RedisDep,
) -> DriverBalanceRead:
    """DRV-5: the calling driver's current owed balance plus recent settlement
    history (backs the Flutter earnings & balance screen).

    "Recent settlements" is every `payout` driver_ledger row for this driver, newest
    first, capped at 20 — the same row shape both LED-4's per-driver settle and
    FLT-2's fleet settle write, so a fleet settlement shows up here too.
    """
    await _get_profile_or_404(session, user.id)
    owed = await driver_owed_balance(session, user.id)
    settlement_config = await get_config(session, redis, "settlement") or {}
    balance_cap = settlement_config.get("balance_cap")
    entries = (
        await session.scalars(
            select(DriverLedgerEntry)
            .where(
                DriverLedgerEntry.driver_id == user.id,
                DriverLedgerEntry.entry_type == LedgerEntryType.payout,
            )
            .order_by(DriverLedgerEntry.created_at.desc())
            .limit(RECENT_SETTLEMENTS_LIMIT)
        )
    ).all()
    return DriverBalanceRead(
        owed_cents=owed,
        balance_cap_cents=balance_cap,
        recent_settlements=[
            DriverSettlementRead(
                id=str(e.id), amount_cents=e.net, settled_at=e.created_at, note=e.note
            )
            for e in entries
        ],
    )


@router.post("/me/settle", response_model=DriverSettleResponse)
async def settle_my_balance(
    body: DriverSettleRequest, user: CurrentUser, session: SessionDep
) -> DriverSettleResponse:
    """PAY-3: "pay my balance" — creates a Wompi checkout (Nequi/PSE) for
    `body.amount` of the driver's owed commission. The actual balance
    reduction (a `payout` driver_ledger row, same shape LED-4's admin
    settlement writes) happens once Wompi's webhook reports the payment
    `approved` (`app/api/payments.py`) — this endpoint only starts the
    checkout, it never settles anything itself.
    """
    await _get_profile_or_404(session, user.id)
    if body.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="amount must be positive"
        )
    owed = await driver_owed_balance(session, user.id)
    if owed <= 0:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No balance owed")
    if body.amount > owed:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="amount exceeds the owed balance",
        )

    reference = f"settlement_{user.id}_{uuid.uuid4().hex}"
    gateway = WompiGateway()
    try:
        checkout = await gateway.create_checkout(
            session,
            reference=reference,
            amount=body.amount,
            customer_email=user.email or f"{user.id}@thecrane.app",
            payment_method_type=body.payment_method,
        )
    except WompiNotConfiguredError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    except WompiApiError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    await session.commit()
    return DriverSettleResponse(
        payment_reference=checkout.payment.reference,
        async_payment_url=checkout.async_payment_url,
    )
