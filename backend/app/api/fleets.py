"""Fleets router (FLT-1): a fleet owner creates their fleet and attaches/detaches
trucks. Mirrors AUTH-5's "acting on your own resources" pattern in app/api/drivers.py
(POST /v1/drivers/me/register) — the caller acts on their own fleet via `/me`, never
by fleet id, and creating a fleet flips the caller's role the same way registering as
a driver does.

Consent: FLT-4 (a later, Flutter-facing task) is where a fleet owner invites/assigns a
specific driver to a truck with that driver's consent. That flow doesn't exist yet, so
for now a fleet owner may attach any truck that isn't already claimed by another fleet
(`fleet_id is None`) — the same "unclaimed resource" gate AUTH-5's plate-uniqueness
check uses, just on `fleet_id` instead. This is a deliberate judgment call pending FLT-4.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import CurrentUser
from app.models.driver import Truck
from app.models.fleet import Fleet
from app.models.user import User, UserRole
from app.schemas.driver import TruckRead
from app.schemas.fleet import FleetBalanceRead, FleetCreate, FleetMemberBalance, FleetRead
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
    trucks = (await session.scalars(select(Truck).where(Truck.fleet_id == fleet.id))).all()
    return FleetRead(
        id=fleet.id,
        owner_user_id=fleet.owner_user_id,
        name=fleet.name,
        created_at=fleet.created_at,
        trucks=[TruckRead.model_validate(t) for t in trucks],
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
