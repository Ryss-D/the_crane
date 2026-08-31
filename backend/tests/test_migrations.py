"""Apply the full alembic chain against a throwaway sqlite file DB.

Proves the migrations are linear, sqlite-compatible (postgres-only bits are guarded),
and produce the tables the models expect. Runs sync on purpose: alembic's env.py calls
asyncio.run, which must not happen inside a running event loop.
"""

import sqlite3
from pathlib import Path

import pytest
from alembic.config import Config

from alembic import command
from app.core.config import get_settings

BACKEND_DIR = Path(__file__).resolve().parents[1]

EXPECTED_TABLES = {
    "users",
    "driver_profiles",
    "trucks",
    "customer_vehicles",
    "jobs",
    "job_offers",
    "driver_location_snapshots",
    "payments",
    "payment_events",
    "driver_ledger",
    "payouts",
    "platform_config",
    "platform_config_audit",
    "ratings",
    "fleets",
    "driver_invites",
}


def test_upgrade_head_on_sqlite(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    db_path = tmp_path / "migrations.db"
    monkeypatch.setenv("DATABASE_URL", f"sqlite+aiosqlite:///{db_path}")
    get_settings.cache_clear()  # env.py reads the (lru-cached) settings for the URL
    try:
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
        command.upgrade(cfg, "head")
    finally:
        get_settings.cache_clear()

    conn = sqlite3.connect(db_path)
    try:
        tables = {
            row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
        }
        assert tables >= EXPECTED_TABLES

        # 0002: users.name/phone relaxed to nullable for sync-before-profile-completion.
        columns = {row[1]: row for row in conn.execute("PRAGMA table_info(users)")}
        assert columns["name"][3] == 0  # notnull flag off
        assert columns["phone"][3] == 0

        # 0006: driver_ledger gains a nullable `note` column (ADM-2 settlement memos).
        ledger_columns = {row[1]: row for row in conn.execute("PRAGMA table_info(driver_ledger)")}
        assert ledger_columns["note"][3] == 0  # notnull flag off

        # 0007: trucks.fleet_id gains its FK to fleets (existing column, was FK-less).
        fk_targets = {
            fk[2] for fk in conn.execute("PRAGMA foreign_key_list(trucks)") if fk[3] == "fleet_id"
        }
        assert fk_targets == {"fleets"}

        # 0008: customer_vehicles gains created_at (CUS-6's newest-first ordering).
        vehicle_columns = {row[1] for row in conn.execute("PRAGMA table_info(customer_vehicles)")}
        assert "created_at" in vehicle_columns

        # 0009: driver_invites (FLT-4's phone-invite table) has a unique token index.
        invite_indexes = {
            row[1] for row in conn.execute("PRAGMA index_list(driver_invites)") if row[2]
        }
        assert "ix_driver_invites_token" in invite_indexes

        # 0010: payment_events.dedup_key (PAY-1) is unique per payment.
        payment_event_columns = {
            row[1] for row in conn.execute("PRAGMA table_info(payment_events)")
        }
        assert "dedup_key" in payment_event_columns

        # 0011: payments.job_id is nullable (PAY-3 driver settlements aren't
        # tied to a job).
        payments_job_id_col = next(
            row for row in conn.execute("PRAGMA table_info(payments)") if row[1] == "job_id"
        )
        assert payments_job_id_col[3] == 0  # `notnull` flag off

        head = conn.execute("SELECT version_num FROM alembic_version").fetchone()
        assert head == ("0011",)
    finally:
        conn.close()
