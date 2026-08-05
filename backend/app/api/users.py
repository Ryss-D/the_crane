from fastapi import APIRouter

from app.core.security import CurrentUser
from app.models.user import User
from app.schemas.user import UserRead

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserRead)
async def read_me(user: CurrentUser) -> User:
    """Minimal protected route proving the auth dependency chain (AUTH-2 fleshes it out)."""
    return user
