"""Fleets router (FLT-1): a fleet owner creates their fleet and attaches/detaches
trucks. Mirrors AUTH-5's "acting on your own resources" pattern in app/api/drivers.py
(POST /v1/drivers/me/register) — the caller acts on their own fleet via `/me`, never
by fleet id, and creating a fleet flips the caller's role the same way registering as
a driver does.

Consent: for a truck that already exists unclaimed (`fleet_id is None`), a fleet owner
may attach it directly (`POST /me/trucks/{truck_id}` below) with no consent step — the
same "unclaimed resource" gate AUTH-5's plate-uniqueness check uses, just on `fleet_id`
instead. FLT-4 adds the other half: inviting a driver who has no truck (or no account)
yet, via `POST /me/invites` below + `POST /v1/drivers/me/register`'s `invite_token` --
that flow *is* consent-shaped, since nothing links to the fleet until the invited
driver themselves redeems the token.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import CurrentUser
from app.models.driver import DriverProfile, Truck
from app.models.fleet import DriverInvite, Fleet, InviteStatus
from app.models.user import User, UserRole
from app.schemas.driver import TruckRead
from app.schemas.fleet import (
    FleetBalanceRead,
    FleetCreate,
    FleetMemberBalance,
    FleetRead,
    InviteCreate,
    InviteRead,
)
from app.services.ledger import fleet_member_balances

router = APIRouter(prefix="/fleets", tags=["fleets"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def _get_fleet_or_404(session: AsyncSession, owner_user_id: uuid.UUID) -> Fleet:
    fleet = await session.scalar(select(Fleet).where(Fleet.owner_user_id == owner_user_id))
    if fleet is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fleet not found — create one first (POST /v1/fleets/me)",
        )
    return fleet


async def _serialize_fleet(session: AsyncSession, fleet: Fleet) -> FleetRead:
    """FLT-3 needs live per-truck status at a glance -- neither it (on
    driver_profiles) nor the driver's name (on users) lives on Truck itself,
    so this batches one query for each across every truck in the fleet
    rather than N+1-ing per truck."""
    trucks = (await session.scalars(select(Truck).where(Truck.fleet_id == fleet.id))).all()
    driver_ids = [t.driver_id for t in trucks if t.driver_id is not None]
    statuses = (
        {
            p.user_id: p.status
            for p in (
                await session.scalars(
                    select(DriverProfile).where(DriverProfile.user_id.in_(driver_ids))
                )
            )
        }
        if driver_ids
        else {}
    )
    names = (
        {u.id: u.name for u in (await session.scalars(select(User).where(User.id.in_(driver_ids))))}
        if driver_ids
        else {}
    )
    return FleetRead(
        id=fleet.id,
        owner_user_id=fleet.owner_user_id,
        name=fleet.name,
        created_at=fleet.created_at,
        trucks=[
            TruckRead(
                id=t.id,
                plate=t.plate,
                type=t.type,
                capacity=t.capacity,
                driver_id=t.driver_id,
                fleet_id=t.fleet_id,
                driver_status=statuses.get(t.driver_id) if t.driver_id else None,
                driver_name=names.get(t.driver_id) if t.driver_id else None,
            )
            for t in trucks
        ],
    )


@router.post("/me", response_model=FleetRead, status_code=status.HTTP_201_CREATED)
async def create_fleet(body: FleetCreate, user: CurrentUser, session: SessionDep) -> FleetRead:
    """FLT-1: create the caller's fleet and flip role -> fleet_owner.

    409 if the caller already owns a fleet (one fleet per owner, same convention as
    driver_profiles' unique user_id).
    """
    existing = await session.scalar(select(Fleet).where(Fleet.owner_user_id == user.id))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already owns a fleet")
    fleet = Fleet(owner_user_id=user.id, name=body.name)
    user.role = UserRole.fleet_owner
    session.add(fleet)
    await session.commit()
    await session.refresh(fleet)
    return await _serialize_fleet(session, fleet)


@router.get("/me", response_model=FleetRead)
async def get_my_fleet(user: CurrentUser, session: SessionDep) -> FleetRead:
    """The caller's fleet plus every truck currently attached to it."""
    fleet = await _get_fleet_or_404(session, user.id)
    return await _serialize_fleet(session, fleet)


@router.get("/trucks/by-plate/{plate}", response_model=TruckRead)
async def find_truck_by_plate(plate: str, user: CurrentUser, session: SessionDep) -> TruckRead:
    """FLT-4: look up a truck before attaching it -- a fleet owner knows a driver's
    plate, not their truck's UUID. Any authenticated user may look up any plate
    (plates aren't secret; this doesn't expose anything `add_truck_to_fleet` below
    wouldn't already reveal via its 404/409 either way) -- callers only get to act
    on the result via the existing per-fleet attach endpoint's own checks."""
    truck = await session.scalar(select(Truck).where(Truck.plate == plate))
    if truck is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Truck not found")
    return TruckRead.model_validate(truck)


@router.post("/me/trucks/{truck_id}", response_model=FleetRead)
async def add_truck_to_fleet(
    truck_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> FleetRead:
    """Attach an unclaimed truck (fleet_id is null) to the caller's fleet.

    404 if the caller has no fleet or the truck doesn't exist; 409 if the truck
    already belongs to a fleet (its own or someone else's — detach it first).
    """
    fleet = await _get_fleet_or_404(session, user.id)
    truck = await session.get(Truck, truck_id)
    if truck is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Truck not found")
    if truck.fleet_id is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Truck already belongs to a fleet"
        )
    truck.fleet_id = fleet.id
    await session.commit()
    return await _serialize_fleet(session, fleet)


@router.delete("/me/trucks/{truck_id}", response_model=FleetRead)
async def remove_truck_from_fleet(
    truck_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> FleetRead:
    """Detach a truck from the caller's fleet. 404 if it isn't currently a member."""
    fleet = await _get_fleet_or_404(session, user.id)
    truck = await session.get(Truck, truck_id)
    if truck is None or truck.fleet_id != fleet.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Truck is not a member of this fleet"
        )
    truck.fleet_id = None
    await session.commit()
    return await _serialize_fleet(session, fleet)


@router.get("/me/balance", response_model=FleetBalanceRead)
async def get_my_fleet_balance(user: CurrentUser, session: SessionDep) -> FleetBalanceRead:
    """FLT-2: consolidated owed balance across every driver in the caller's fleet,
    plus the per-driver breakdown it's built from (app/services/ledger.py)."""
    fleet = await _get_fleet_or_404(session, user.id)
    balances = await fleet_member_balances(session, fleet.id)
    names = (
        {u.id: u.name for u in (await session.scalars(select(User).where(User.id.in_(balances))))}
        if balances
        else {}
    )
    members = [
        FleetMemberBalance(driver_id=driver_id, name=names.get(driver_id), owed_balance=owed)
        for driver_id, owed in balances.items()
    ]
    return FleetBalanceRead(fleet_id=fleet.id, owed_balance=sum(balances.values()), members=members)


# ---- FLT-4: phone invite -> signup lands pre-linked ---------------------------


@router.post("/me/invites", response_model=InviteRead, status_code=status.HTTP_201_CREATED)
async def create_invite(body: InviteCreate, user: CurrentUser, session: SessionDep) -> InviteRead:
    """FLT-4: invite a driver who doesn't have a truck (or an account) yet.

    Pre-provisions the Truck row up front (unclaimed by a driver, `fleet_id` = the
    caller's fleet) and hands back a token; the invited driver redeems it via
    `invite_token` on POST /v1/drivers/me/register, which links them onto this exact
    truck instead of creating a new one.

    409 if `phone` already has a pending invite (redeem or let it be superseded
    first), or if `plate` is already taken — mirrors AUTH-5's plate-uniqueness
    IntegrityError handling in app/api/drivers.py's register_driver.
    """
    fleet = await _get_fleet_or_404(session, user.id)

    existing = await session.scalar(
        select(DriverInvite).where(
            DriverInvite.phone == body.phone, DriverInvite.status == InviteStatus.pending
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Phone already has a pending invite"
        )

    truck = Truck(plate=body.plate, type=body.truck_type, capacity=body.capacity, fleet_id=fleet.id)
    session.add(truck)
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Plate already registered"
        ) from exc

    invite = DriverInvite(fleet_id=fleet.id, truck_id=truck.id, phone=body.phone)
    session.add(invite)
    await session.commit()
    return InviteRead(invite_token=invite.token, truck_id=truck.id, phone=invite.phone)


@router.get("/me/invites", response_model=list[InviteRead])
async def list_my_invites(user: CurrentUser, session: SessionDep) -> list[InviteRead]:
    """Pending invites the caller's fleet has outstanding (not yet redeemed)."""
    fleet = await _get_fleet_or_404(session, user.id)
    invites = (
        await session.scalars(
            select(DriverInvite).where(
                DriverInvite.fleet_id == fleet.id, DriverInvite.status == InviteStatus.pending
            )
        )
    ).all()
    return [InviteRead(invite_token=i.token, truck_id=i.truck_id, phone=i.phone) for i in invites]
