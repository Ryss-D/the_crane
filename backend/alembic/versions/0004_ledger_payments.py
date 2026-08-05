"""LED-1 (tables only): payments, payment_events, payouts, driver_ledger

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-04
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _uuid_pk(is_postgres: bool) -> sa.Column:
    return sa.Column(
        "id",
        sa.Uuid(),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()") if is_postgres else None,
    )


def _json() -> sa.types.TypeEngine:
    return sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "payments",
        _uuid_pk(is_postgres),
        sa.Column("job_id", sa.Uuid(), sa.ForeignKey("jobs.id"), nullable=False),
        sa.Column(
            "provider",
            sa.Enum(
                "cash",
                "wompi",
                "mercadopago",
                name="payment_provider",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("provider_ref", sa.String(length=128), nullable=True),
        sa.Column("reference", sa.String(length=64), nullable=False),
        sa.Column("amount", sa.Numeric(12, 0), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column(
            "method",
            sa.Enum(
                "cash",
                "card",
                "pse",
                "nequi",
                "wallet",
                name="payment_method",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.Enum(
                "pending",
                "processing",
                "approved",
                "declined",
                "expired",
                "refunded",
                name="payment_status",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("raw_webhook", _json(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("settled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_payments_job_id", "payments", ["job_id"])
    op.create_index("ix_payments_reference", "payments", ["reference"], unique=True)

    op.create_table(
        "payment_events",
        _uuid_pk(is_postgres),
        sa.Column("payment_id", sa.Uuid(), sa.ForeignKey("payments.id"), nullable=False),
        sa.Column("payload", _json(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_payment_events_payment_id", "payment_events", ["payment_id"])

    op.create_table(
        "payouts",
        _uuid_pk(is_postgres),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("amount", sa.Numeric(12, 0), nullable=False),
        sa.Column("period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("period_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "status",
            sa.Enum("pending", "paid", name="payout_status", native_enum=False, length=20),
            nullable=False,
        ),
        sa.Column("provider_ref", sa.String(length=128), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_payouts_driver_id", "payouts", ["driver_id"])

    op.create_table(
        "driver_ledger",
        _uuid_pk(is_postgres),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("job_id", sa.Uuid(), sa.ForeignKey("jobs.id"), nullable=True),
        sa.Column("gross", sa.Numeric(12, 0), nullable=False),
        sa.Column("commission", sa.Numeric(12, 0), nullable=False),
        sa.Column("net", sa.Numeric(12, 0), nullable=False),
        sa.Column(
            "entry_type",
            sa.Enum(
                "earning",
                "payout",
                "adjustment",
                name="ledger_entry_type",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("payout_id", sa.Uuid(), sa.ForeignKey("payouts.id"), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_driver_ledger_driver_id", "driver_ledger", ["driver_id"])


def downgrade() -> None:
    op.drop_table("driver_ledger")
    op.drop_table("payouts")
    op.drop_table("payment_events")
    op.drop_table("payments")
