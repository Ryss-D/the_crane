"""Firebase ID-token verification dependencies.

The actual token verifier is provided by the `get_token_verifier` dependency so tests
can override it (`app.dependency_overrides[get_token_verifier] = ...`) without touching
Firebase. firebase_admin is initialized lazily and only when FIREBASE_CREDENTIALS_PATH
is set, so the app boots without credentials.
"""

from collections.abc import Callable
from typing import Annotated, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session
from app.models.user import User, UserRole

TokenVerifier = Callable[[str], dict[str, Any]]

_bearer_scheme = HTTPBearer(auto_error=False)
_firebase_app: Any = None


def _init_firebase() -> None:
    global _firebase_app
    if _firebase_app is not None:
        return
    settings = get_settings()
    if not settings.firebase_credentials_path:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase credentials are not configured",
        )
    import firebase_admin
    from firebase_admin import credentials

    cred = credentials.Certificate(settings.firebase_credentials_path)
    _firebase_app = firebase_admin.initialize_app(cred)


def _verify_firebase_token(token: str) -> dict[str, Any]:
    _init_firebase()
    from firebase_admin import auth

    return auth.verify_id_token(token)


def get_token_verifier() -> TokenVerifier:
    """Dependency returning the token verifier; override in tests."""
    return _verify_firebase_token


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_verified_claims(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)],
    verifier: Annotated[TokenVerifier, Depends(get_token_verifier)],
) -> dict[str, Any]:
    """Verify the bearer token and return its claims (guaranteed to carry a uid/sub)."""
    if credentials is None:
        raise _unauthorized("Missing bearer token")
    try:
        claims = verifier(credentials.credentials)
    except HTTPException:
        raise
    except Exception as exc:
        raise _unauthorized("Invalid or expired token") from exc

    if not (claims.get("uid") or claims.get("sub")):
        raise _unauthorized("Token has no uid claim")
    return claims


def claims_uid(claims: dict[str, Any]) -> str:
    """Firebase uid from verified claims (`uid` in firebase_admin, `sub` in raw JWTs)."""
    return claims.get("uid") or claims["sub"]


async def get_current_user(
    claims: Annotated[dict[str, Any], Depends(get_verified_claims)],
    session: Annotated[AsyncSession, Depends(get_session)],
) -> User:
    """Resolve `Authorization: Bearer <firebase_id_token>` to a users row."""
    user = await session.scalar(select(User).where(User.firebase_uid == claims_uid(claims)))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found — call /v1/auth/sync first",
        )
    return user


async def require_admin(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required",
        )
    return user


VerifiedClaims = Annotated[dict[str, Any], Depends(get_verified_claims)]
CurrentUser = Annotated[User, Depends(get_current_user)]
AdminUser = Annotated[User, Depends(require_admin)]
