"""initial: postgis extension + users table

Revision ID: 0001
Revises:
Create Date: 2026-08-04
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    is_postgres = bind.dialect.name == "postgresql"

    # PostGIS is required for geo queries (jobs, dispatch). Skipped on sqlite (tests).
    if is_postgres:
        op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "users",
        sa.Column(
            "id",
            sa.Uuid(),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()") if is_postgres else None,
        ),
        sa.Column("firebase_uid", sa.String(length=128), nullable=False),
        sa.Column(
            "role",
            sa.Enum(
                "customer",
                "driver",
                "admin",
                "fleet_owner",
                name="user_role",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=False),
        sa.Column("email", sa.String(length=254), nullable=True),
        sa.Column("fcm_token", sa.String(length=512), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_firebase_uid", table_name="users")
    op.drop_table("users")
    # The postgis extension is left installed on purpose (shared, cheap, idempotent).
