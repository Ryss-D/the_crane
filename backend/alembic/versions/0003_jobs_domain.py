"""JOB-1: driver_profiles, trucks, customer_vehicles, jobs, job_offers, location snapshots

Revision ID: 0003
Revises: 0002
Create Date: 2026-08-04

Geometry note: jobs.pickup/dropoff are plain lat/lng float columns for now (sqlite-safe,
service-free tests). PostGIS geometry(Point, 4326) columns + the GiST index on pickup
arrive with the dispatch geo work (DSP-1).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _uuid_pk(is_postgres: bool) -> sa.Column:
    return sa.Column(
        "id",
        sa.Uuid(),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()") if is_postgres else None,
    )


def _vehicle_type() -> sa.Enum:
    return sa.Enum("moto", "car", "suv", name="vehicle_type", native_enum=False, length=20)


def _job_status() -> sa.Enum:
    return sa.Enum(
        "requested",
        "matching",
        "assigned",
        "en_route_pickup",
        "arrived_pickup",
        "loading",
        "in_transit",
        "delivered",
        "completed",
        "cancelled",
        "no_drivers",
        name="job_status",
        native_enum=False,
        length=20,
    )


def upgrade() -> None:
    is_postgres = op.get_bind().dialect.name == "postgresql"

    op.create_table(
        "driver_profiles",
        _uuid_pk(is_postgres),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "status",
            sa.Enum(
                "offline",
                "available",
                "on_job",
                name="driver_status",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("verified", sa.Boolean(), nullable=False),
        sa.Column("license_url", sa.String(length=512), nullable=True),
        sa.Column("truck_photo_url", sa.String(length=512), nullable=True),
        sa.Column("rating_avg", sa.Numeric(3, 2), nullable=True),
    )
    op.create_index("ix_driver_profiles_user_id", "driver_profiles", ["user_id"], unique=True)

    op.create_table(
        "trucks",
        _uuid_pk(is_postgres),
        sa.Column("plate", sa.String(length=16), nullable=False, unique=True),
        sa.Column(
            "type",
            sa.Enum(
                "moto_only", "flatbed", "standard", name="truck_type", native_enum=False, length=20
            ),
            nullable=False,
        ),
        sa.Column(
            "capacity",
            sa.Enum("moto", "car", "both", name="truck_capacity", native_enum=False, length=20),
            nullable=False,
        ),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=True),
        # No FK: fleets table arrives in Phase 6 (FLT-1), which adds the constraint.
        sa.Column("fleet_id", sa.Uuid(), nullable=True),
    )
    op.create_index("ix_trucks_driver_id", "trucks", ["driver_id"])

    op.create_table(
        "customer_vehicles",
        _uuid_pk(is_postgres),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", _vehicle_type(), nullable=False),
        sa.Column("make", sa.String(length=60), nullable=True),
        sa.Column("model", sa.String(length=60), nullable=True),
        sa.Column("plate", sa.String(length=16), nullable=True),
    )
    op.create_index("ix_customer_vehicles_user_id", "customer_vehicles", ["user_id"])

    op.create_table(
        "jobs",
        _uuid_pk(is_postgres),
        sa.Column("customer_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("vehicle_type", _vehicle_type(), nullable=False),
        sa.Column("status", _job_status(), nullable=False),
        sa.Column("pickup_lat", sa.Float(), nullable=False),
        sa.Column("pickup_lng", sa.Float(), nullable=False),
        sa.Column("dropoff_lat", sa.Float(), nullable=False),
        sa.Column("dropoff_lng", sa.Float(), nullable=False),
        sa.Column("pickup_address", sa.Text(), nullable=False),
        sa.Column("dropoff_address", sa.Text(), nullable=False),
        sa.Column("distance_km", sa.Numeric(8, 2), nullable=True),
        # COP: no decimals.
        sa.Column("quoted_price", sa.Numeric(12, 0), nullable=True),
        sa.Column("final_price", sa.Numeric(12, 0), nullable=True),
        sa.Column(
            "payment_method",
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
            "config_snapshot",
            sa.JSON().with_variant(postgresql.JSONB(), "postgresql"),
            nullable=True,
        ),
        sa.Column(
            "requested_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("picked_up_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_reason", sa.String(length=255), nullable=True),
        sa.Column("share_token", sa.Uuid(), nullable=False),
    )
    op.create_index("ix_jobs_customer_id", "jobs", ["customer_id"])
    op.create_index("ix_jobs_driver_id", "jobs", ["driver_id"])
    op.create_index("ix_jobs_status", "jobs", ["status"])
    op.create_index("ix_jobs_share_token", "jobs", ["share_token"], unique=True)

    op.create_table(
        "job_offers",
        _uuid_pk(is_postgres),
        sa.Column("job_id", sa.Uuid(), sa.ForeignKey("jobs.id"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "offered_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "response",
            sa.Enum(
                "pending",
                "accepted",
                "rejected",
                "timeout",
                name="offer_response",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
    )
    op.create_index("ix_job_offers_job_id", "job_offers", ["job_id"])
    op.create_index("ix_job_offers_driver_id", "job_offers", ["driver_id"])

    op.create_table(
        "driver_location_snapshots",
        _uuid_pk(is_postgres),
        sa.Column("job_id", sa.Uuid(), sa.ForeignKey("jobs.id"), nullable=False),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("job_status", _job_status(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_driver_location_snapshots_job_id", "driver_location_snapshots", ["job_id"])


def downgrade() -> None:
    op.drop_table("driver_location_snapshots")
    op.drop_table("job_offers")
    op.drop_table("jobs")
    op.drop_table("customer_vehicles")
    op.drop_table("trucks")
    op.drop_table("driver_profiles")
