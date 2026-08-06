"""Customer saved-vehicles API (CUS-6): CRUD over the pre-existing customer_vehicles
table (created in JOB-1 for POST /v1/jobs' optional `customer_vehicle_id`, but never
had its own CRUD endpoints until now). Scoped to the authenticated user throughout --
no vehicle id is ever looked up outside a `user_id == caller` filter, same ownership
pattern app/api/drivers.py uses for the caller's own driver profile/truck.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import CurrentUser
from app.models.job import CustomerVehicle
from app.schemas.vehicle import VehicleCreate, VehicleRead, VehicleUpdate

router = APIRouter(prefix="/me/vehicles", tags=["vehicles"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def _get_owned_vehicle_or_404(
    session: AsyncSession, vehicle_id: uuid.UUID, user_id: uuid.UUID
) -> CustomerVehicle:
    vehicle = await session.scalar(
        select(CustomerVehicle).where(
            CustomerVehicle.id == vehicle_id, CustomerVehicle.user_id == user_id
        )
    )
    if vehicle is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found")
    return vehicle


@router.get("", response_model=list[VehicleRead])
async def list_my_vehicles(user: CurrentUser, session: SessionDep) -> list[CustomerVehicle]:
    """Every saved vehicle for the caller, most-recently-created first."""
    return list(
        await session.scalars(
            select(CustomerVehicle)
            .where(CustomerVehicle.user_id == user.id)
            .order_by(CustomerVehicle.created_at.desc())
        )
    )


@router.post("", response_model=VehicleRead, status_code=status.HTTP_201_CREATED)
async def create_my_vehicle(
    body: VehicleCreate, user: CurrentUser, session: SessionDep
) -> CustomerVehicle:
    vehicle = CustomerVehicle(
        user_id=user.id, type=body.type, make=body.make, model=body.model, plate=body.plate
    )
    session.add(vehicle)
    await session.commit()
    await session.refresh(vehicle)
    return vehicle


@router.patch("/{vehicle_id}", response_model=VehicleRead)
async def update_my_vehicle(
    vehicle_id: uuid.UUID, body: VehicleUpdate, user: CurrentUser, session: SessionDep
) -> CustomerVehicle:
    """404 if the vehicle doesn't exist or isn't the caller's. Fields absent from the
    body (as opposed to explicitly null) are left untouched, same convention as
    PATCH /v1/me (app/api/users.py)."""
    vehicle = await _get_owned_vehicle_or_404(session, vehicle_id, user.id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(vehicle, field, value)
    await session.commit()
    await session.refresh(vehicle)
    return vehicle


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_vehicle(vehicle_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> None:
    """404 if the vehicle doesn't exist or isn't the caller's."""
    vehicle = await _get_owned_vehicle_or_404(session, vehicle_id, user.id)
    await session.delete(vehicle)
    await session.commit()
