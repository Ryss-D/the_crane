import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.user import UserRole


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    firebase_uid: str
    role: UserRole
    name: str
    phone: str
    email: str | None
    fcm_token: str | None
    created_at: datetime
