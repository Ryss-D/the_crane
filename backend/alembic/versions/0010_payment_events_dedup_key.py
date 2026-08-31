"""PAY-1: payment_events.dedup_key (+ unique constraint with payment_id) for
idempotent Wompi webhook handling.

Revision ID: 0010
Revises: 0009
Create Date: 2026-08-30
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # batch_alter_table: SQLite can't ALTER TABLE ADD COLUMN NOT NULL + add a
    # constraint in separate direct statements the way Postgres can — batch
    # mode recreates the table under the hood on SQLite, and is a no-op
    # wrapper (plain ALTER TABLE) on Postgres. Matches 0007's precedent for
    # altering an existing table.
    with op.batch_alter_table("payment_events") as batch:
        batch.add_column(
            sa.Column("dedup_key", sa.String(length=160), nullable=False, server_default="")
        )
        batch.create_unique_constraint(
            "uq_payment_events_payment_dedup", ["payment_id", "dedup_key"]
        )


def downgrade() -> None:
    with op.batch_alter_table("payment_events") as batch:
        batch.drop_constraint("uq_payment_events_payment_dedup", type_="unique")
        batch.drop_column("dedup_key")
