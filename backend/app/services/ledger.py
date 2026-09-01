"""Driver balance helper — what a driver currently owes the platform.

Used by DSP-1's balance-cap gate (going `available` is blocked when the owed
balance reaches `settlement.balance_cap`); the LED settlement tasks build on it.

Convention: on `earning` rows the `commission` column is the COP amount the
driver owes the platform for a cash job (the driver kept the fare). `payout`
and `adjustment` rows record settlements/corrections with `net` as the settled
COP amount. Balance owed = sum(earning commissions) - sum(payout/adjustment nets).

FLT-2 adds the fleet rollup: ledger entries don't carry fleet attribution
directly (there's no fleet_id column on driver_ledger) — a driver's fleet is
found via their truck (trucks.driver_id -> trucks.fleet_id), and the fleet's
owed balance is just the sum of driver_owed_balance() across its member
drivers. That sum is linear, so it's always exactly the "sum of member driver
balances" the FLT-2 AC asks for.
"""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver import Truck
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


async def fleet_member_driver_ids(session: AsyncSession, fleet_id: uuid.UUID) -> list[uuid.UUID]:
    """Every driver currently assigned a truck that belongs to this fleet."""
    rows = await session.scalars(
        select(Truck.driver_id).where(Truck.fleet_id == fleet_id, Truck.driver_id.is_not(None))
    )
    return list(rows)


async def fleet_member_balances(session: AsyncSession, fleet_id: uuid.UUID) -> dict[uuid.UUID, int]:
    """Owed balance per member driver, keyed by driver_id."""
    driver_ids = await fleet_member_driver_ids(session, fleet_id)
    return {driver_id: await driver_owed_balance(session, driver_id) for driver_id in driver_ids}


async def fleet_member_truck_ids(
    session: AsyncSession, fleet_id: uuid.UUID
) -> dict[uuid.UUID, uuid.UUID]:
    """ADM-7 admin override (2026-08-31): each member driver's current truck within
    the fleet, keyed by driver_id — lets a balance-breakdown view (FleetMemberBalance)
    link straight to POST/DELETE /v1/admin/trucks/{truck_id}/assign-driver without a
    separate per-driver truck lookup."""
    rows = (
        await session.execute(
            select(Truck.driver_id, Truck.id).where(
                Truck.fleet_id == fleet_id, Truck.driver_id.is_not(None)
            )
        )
    ).all()
    return {driver_id: truck_id for driver_id, truck_id in rows}


async def fleet_owed_balance(session: AsyncSession, fleet_id: uuid.UUID) -> int:
    """COP the fleet owes the platform — sum of every member driver's owed balance."""
    balances = await fleet_member_balances(session, fleet_id)
    return sum(balances.values())


async def driver_fleet_id(session: AsyncSession, driver_id: uuid.UUID) -> uuid.UUID | None:
    """The fleet_id of the truck currently assigned to this driver, if any."""
    return await session.scalar(
        select(Truck.fleet_id).where(Truck.driver_id == driver_id, Truck.fleet_id.is_not(None))
    )


def apportion(amount: int, weights: list[int]) -> list[int]:
    """Split `amount` across `weights` proportionally, largest-remainder rounding so
    the shares always sum to exactly `amount` (COP has no sub-unit to absorb drift).

    Negative/zero weights don't buy a larger share but also aren't excluded outright
    -- a driver who's already settled (owed <= 0) still gets a (possibly zero) share
    rather than blowing up the split. If every weight is <= 0 the amount is split as
    evenly as possible instead (nobody currently owes anything, but the fleet
    settlement should still land somewhere rather than error).
    """
    if not weights:
        return []
    clamped = [max(w, 0) for w in weights]
    total_weight = sum(clamped)
    n = len(weights)
    if total_weight <= 0:
        base, extra = divmod(amount, n)
        return [base + (1 if i < extra else 0) for i in range(n)]

    shares = [amount * w // total_weight for w in clamped]
    remainders = [(amount * w) % total_weight for w in clamped]
    remaining = amount - sum(shares)
    # Largest remainder first; ties broken by original order for determinism.
    order = sorted(range(n), key=lambda i: remainders[i], reverse=True)
    for i in order[:remaining]:
        shares[i] += 1
    return shares
