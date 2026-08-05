"""RAT-1 + ADM-2: ratings table, driver_ledger.note column

`driver_profiles.status` gains a Python-only `blocked` value (app/models/driver.py) —
no DDL needed since that column is a plain VARCHAR (native_enum=False).

Revision ID: 0006
Revises: 0005
Create Date: 2026-08-05
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "ratings",
        sa.Column(
            "id",
            sa.Uuid(),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()") if is_postgres else None,
        ),
        sa.Column("job_id", sa.Uuid(), sa.ForeignKey("jobs.id"), nullable=False),
        sa.Column("from_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("to_user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("stars >= 1 AND stars <= 5", name="ck_ratings_stars_range"),
        sa.UniqueConstraint("job_id", "from_user_id", name="uq_ratings_job_id_from_user_id"),
    )
    op.create_index("ix_ratings_job_id", "ratings", ["job_id"])
    op.create_index("ix_ratings_from_user_id", "ratings", ["from_user_id"])
    op.create_index("ix_ratings_to_user_id", "ratings", ["to_user_id"])

    # ADM-2: optional free-text memo for admin-recorded settlements/adjustments.
    op.add_column("driver_ledger", sa.Column("note", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("driver_ledger", "note")
    op.drop_index("ix_ratings_to_user_id", table_name="ratings")
    op.drop_index("ix_ratings_from_user_id", table_name="ratings")
    op.drop_index("ix_ratings_job_id", table_name="ratings")
    op.drop_table("ratings")
