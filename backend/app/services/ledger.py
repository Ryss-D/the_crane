"""Driver balance helper — what a driver currently owes the platform.

Used by DSP-1's balance-cap gate (going `available` is blocked when the owed
balance reaches `settlement.balance_cap`); the LED settlement tasks build on it.

Convention: on `earning` rows the `commission` column is the COP amount the
driver owes the platform for a cash job (the driver kept the fare). `payout`
and `adjustment` rows record settlements/corrections with `net` as the settled
COP amount. Balance owed = sum(earning commissions) - sum(payout/adjustment nets).
"""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ledger import DriverLedgerEntry, LedgerEntryType


async def driver_owed_balance(session: AsyncSession, driver_id: uuid.UUID) -> int:
    """COP the driver owes the platform (may be negative after over-settlement)."""
    accrued = await session.scalar(
        select(func.coalesce(func.sum(DriverLedgerEntry.commission), 0)).where(
            DriverLedgerEntry.driver_id == driver_id,
            DriverLedgerEntry.entry_type == LedgerEntryType.earning,
        )
    )
    settled = await session.scalar(
        select(func.coalesce(func.sum(DriverLedgerEntry.net), 0)).where(
            DriverLedgerEntry.driver_id == driver_id,
            DriverLedgerEntry.entry_type.in_([LedgerEntryType.payout, LedgerEntryType.adjustment]),
        )
    )
    return int(accrued or 0) - int(settled or 0)
