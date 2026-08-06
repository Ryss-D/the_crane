"""FLT-1: fleets table + FK/index on trucks.fleet_id

trucks.fleet_id already exists (nullable, added in 0003 ahead of time for AUTH-5) with
no FK because the fleets table didn't exist yet — this migration creates that table and
adds the constraint + index. batch_alter_table so the ALTER runs on sqlite (tests) too.

Revision ID: 0007
Revises: 0006
Create Date: 2026-08-05
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "fleets",
        sa.Column(
            "id",
            sa.Uuid(),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()") if is_postgres else None,
        ),
        sa.Column("owner_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_fleets_owner_user_id", "fleets", ["owner_user_id"], unique=True)

    with op.batch_alter_table("trucks") as batch:
        batch.create_foreign_key("fk_trucks_fleet_id_fleets", "fleets", ["fleet_id"], ["id"])
    op.create_index("ix_trucks_fleet_id", "trucks", ["fleet_id"])


def downgrade() -> None:
    op.drop_index("ix_trucks_fleet_id", table_name="trucks")
    with op.batch_alter_table("trucks") as batch:
        batch.drop_constraint("fk_trucks_fleet_id_fleets", type_="foreignkey")
    op.drop_index("ix_fleets_owner_user_id", table_name="fleets")
    op.drop_table("fleets")
