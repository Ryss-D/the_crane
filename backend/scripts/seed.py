"""Idempotent dev seed: admin user (firebase_uid "seed-admin") + platform_config defaults.

Run from backend/ (after `alembic upgrade head`):

    uv run python scripts/seed.py

Or inside docker compose:

    docker compose exec api uv run python scripts/seed.py

Existing rows are never overwritten — re-running is always safe.
"""

import asyncio
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import dispose_engine, get_sessionmaker
from app.models.platform_config import PlatformConfig
from app.models.user import User, UserRole

ADMIN_FIREBASE_UID = "seed-admin"

# Amounts in COP (no decimals); see PLAN §2.5.
DEFAULT_CONFIG: dict[str, Any] = {
    "pricing": {
        "moto": {"base": 40000, "per_km": 3500, "min": 50000},
        "car": {"base": 60000, "per_km": 5000, "min": 80000},
        "suv": {"base": 70000, "per_km": 5500, "min": 90000},
    },
    "commission": {"mode": "percent", "rate": {"moto": 0.15, "car": 0.15, "suv": 0.15}},
    "settlement": {"balance_cap": None, "period": "weekly"},
    "dispatch": {
        "offer_ttl_seconds": 30,
        "search_radius_km": 10,
        "radius_widen_factor": 2,
        # Free customer-cancel window after `assigned` (JOB-3).
        "cancel_grace_seconds": 60,
    },
}


async def seed_admin(session: AsyncSession) -> None:
    existing = await session.scalar(select(User).where(User.firebase_uid == ADMIN_FIREBASE_UID))
    if existing is not None:
        print(f"admin user already present (id={existing.id}) — nothing to do")
        return
    admin = User(
        firebase_uid=ADMIN_FIREBASE_UID,
        role=UserRole.admin,
        name="Seed Admin",
        phone="+570000000000",
        email="admin@thecrane.local",
    )
    session.add(admin)
    await session.commit()
    print(f"created admin user (id={admin.id})")


async def seed_platform_config(session: AsyncSession) -> None:
    for key, value in DEFAULT_CONFIG.items():
        existing = await session.scalar(select(PlatformConfig).where(PlatformConfig.key == key))
        if existing is not None:
            print(f"config '{key}' already present — skipping")
            continue
        session.add(PlatformConfig(key=key, value=value))
        print(f"seeded config '{key}'")
    await session.commit()


async def seed() -> None:
    async with get_sessionmaker()() as session:
        await seed_admin(session)
        await seed_platform_config(session)


async def main() -> None:
    try:
        await seed()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
