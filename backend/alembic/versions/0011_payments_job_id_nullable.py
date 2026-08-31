"""PAY-3: payments.job_id nullable -- a driver-balance-settlement payment
(POST /v1/drivers/me/settle) isn't for any one job.

Revision ID: 0011
Revises: 0010
Create Date: 2026-08-31
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.alter_column("job_id", existing_type=sa.Uuid(), nullable=True)


def downgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.alter_column("job_id", existing_type=sa.Uuid(), nullable=False)
