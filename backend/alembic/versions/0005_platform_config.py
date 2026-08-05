"""JOB-2: platform_config + platform_config_audit

Revision ID: 0005
Revises: 0004
Create Date: 2026-08-04
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _json() -> sa.types.TypeEngine:
    return sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "platform_config",
        sa.Column("key", sa.String(length=64), primary_key=True),
        sa.Column("value", _json(), nullable=False),
        sa.Column("updated_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )

    op.create_table(
        "platform_config_audit",
        sa.Column(
            "id",
            sa.Uuid(),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()") if is_postgres else None,
        ),
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("old_value", _json(), nullable=True),
        sa.Column("new_value", _json(), nullable=False),
        sa.Column("changed_by", sa.Uuid(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column(
            "changed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_platform_config_audit_key", "platform_config_audit", ["key"])


def downgrade() -> None:
    op.drop_index("ix_platform_config_audit_key", table_name="platform_config_audit")
    op.drop_table("platform_config_audit")
    op.drop_table("platform_config")
