"""users.name/phone nullable — /v1/auth/sync may run before profile completion (AUTH-2)

Revision ID: 0002
Revises: 0001
Create Date: 2026-08-04
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # batch_alter_table so the same migration runs on sqlite (tests) and postgres.
    with op.batch_alter_table("users") as batch:
        batch.alter_column("name", existing_type=sa.String(length=120), nullable=True)
        batch.alter_column("phone", existing_type=sa.String(length=32), nullable=True)


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.alter_column("phone", existing_type=sa.String(length=32), nullable=False)
        batch.alter_column("name", existing_type=sa.String(length=120), nullable=False)
