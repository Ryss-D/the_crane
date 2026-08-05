from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import CurrentUser
from app.models.user import User
from app.schemas.user import UserRead, UserUpdate

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserRead)
async def read_me(user: CurrentUser) -> User:
    """Return the authenticated user's profile."""
    return user


@router.patch("/me", response_model=UserRead)
async def update_me(
    body: UserUpdate,
    user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> User:
    """Update name/email/fcm_token; fields absent from the body are left untouched."""
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await session.commit()
    await session.refresh(user)
    return user
