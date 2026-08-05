"""AUTH-2: POST /v1/auth/sync — idempotent create-or-fetch after Firebase signup."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import VerifiedClaims, claims_uid
from app.models.user import User, UserRole
from app.schemas.user import AuthSyncRequest, UserRead

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/sync", response_model=UserRead)
async def auth_sync(
    claims: VerifiedClaims,
    session: Annotated[AsyncSession, Depends(get_session)],
    body: AuthSyncRequest | None = None,
) -> User:
    """Create the users row for a fresh Firebase account, or return the existing one.

    Name/phone come from the request body when provided, falling back to token claims;
    both may stay null until profile completion (AUTH-3).
    """
    firebase_uid = claims_uid(claims)
    user = await session.scalar(select(User).where(User.firebase_uid == firebase_uid))
    if user is not None:
        return user

    body = body or AuthSyncRequest()
    user = User(
        firebase_uid=firebase_uid,
        role=UserRole.customer,
        name=body.name or claims.get("name"),
        phone=body.phone or claims.get("phone_number"),
        email=claims.get("email"),
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError:
        # A concurrent sync won the unique-constraint race — return its row.
        await session.rollback()
        existing = await session.scalar(select(User).where(User.firebase_uid == firebase_uid))
        if existing is None:
            raise
        return existing
    await session.refresh(user)
    return user
