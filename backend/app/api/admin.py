from fastapi import APIRouter

from app.core.security import AdminUser

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/ping")
async def admin_ping(user: AdminUser) -> dict[str, str]:
    """Minimal admin-only route proving `require_admin` (real admin API comes in ADM tasks)."""
    return {"status": "ok", "admin": user.firebase_uid}
