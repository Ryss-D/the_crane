from typing import Any

from sqlalchemy import JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


# JSON column type: JSONB on postgres, plain JSON on sqlite (tests).
JSONValue: Any = JSON().with_variant(JSONB(), "postgresql")
