"""Runtime platform configuration (JOB-2): versioned key/value store + change audit."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JSONValue


class PlatformConfig(Base):
    __tablename__ = "platform_config"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[Any] = mapped_column(JSONValue, nullable=False)
    updated_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class PlatformConfigAudit(Base):
    __tablename__ = "platform_config_audit"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    key: Mapped[str] = mapped_column(String(64), index=True)
    old_value: Mapped[Any] = mapped_column(JSONValue, nullable=True)
    new_value: Mapped[Any] = mapped_column(JSONValue, nullable=False)
    changed_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
