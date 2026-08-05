"""Idempotent dev seed: creates the admin user (firebase_uid "seed-admin").

Run from backend/ (after `alembic upgrade head`):

    uv run python scripts/seed.py

Or inside docker compose:

    docker compose exec api uv run python scripts/seed.py

platform_config seeding will be added when that table lands (Phase 1).
"""

import asyncio

from sqlalchemy import select

from app.core.database import dispose_engine, get_sessionmaker
from app.models.user import User, UserRole

ADMIN_FIREBASE_UID = "seed-admin"


async def seed() -> None:
    async with get_sessionmaker()() as session:
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


async def main() -> None:
    try:
        await seed()
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
