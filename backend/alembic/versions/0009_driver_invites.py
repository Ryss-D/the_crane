"""FLT-4: driver_invites table (phone invite -> signup lands pre-linked)

A fleet owner pre-provisions a Truck (unclaimed, fleet_id set) for a driver who
doesn't have an account yet, and hands out a token that
POST /v1/drivers/me/register redeems, linking the caller onto that truck instead of
creating a new one. Dedicated table rather than nullable columns on Truck -- it has
its own pending -> consumed lifecycle and needs the invited phone number, which
doesn't belong on Truck itself.

Revision ID: 0009
Revises: 0008
Create Date: 2026-08-06
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "driver_invites",
        sa.Column(
            "id",
            sa.Uuid(),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()") if is_postgres else None,
        ),
        sa.Column("fleet_id", sa.Uuid(), sa.ForeignKey("fleets.id"), nullable=False),
        sa.Column("truck_id", sa.Uuid(), sa.ForeignKey("trucks.id"), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=False),
        sa.Column("token", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_driver_invites_fleet_id", "driver_invites", ["fleet_id"])
    op.create_index("ix_driver_invites_truck_id", "driver_invites", ["truck_id"])
    op.create_index("ix_driver_invites_phone", "driver_invites", ["phone"])
    op.create_index("ix_driver_invites_token", "driver_invites", ["token"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_driver_invites_token", table_name="driver_invites")
    op.drop_index("ix_driver_invites_phone", table_name="driver_invites")
    op.drop_index("ix_driver_invites_truck_id", table_name="driver_invites")
    op.drop_index("ix_driver_invites_fleet_id", table_name="driver_invites")
    op.drop_table("driver_invites")
