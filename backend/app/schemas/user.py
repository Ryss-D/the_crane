import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.user import UserRole


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    firebase_uid: str
    role: UserRole
    name: str | None
    phone: str | None
    email: str | None
    fcm_token: str | None
    created_at: datetime


class AuthSyncRequest(BaseModel):
    """Optional profile fields sent alongside /v1/auth/sync (token claims are fallback)."""

    name: str | None = None
    phone: str | None = None


class UserUpdate(BaseModel):
    """PATCH /v1/me body — only provided fields are updated."""

    name: str | None = None
    email: str | None = None
    fcm_token: str | None = None
