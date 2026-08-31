"""PAY-5: nightly reconciliation — diffs Wompi's own view of each local
`payments` row (provider=wompi) against what this app has recorded, and
reports any mismatch.

Deliberately per-transaction (`WompiGateway.get_status`, one call per local
payment needing a check), not a bulk "list transactions" call: Wompi's public
merchant API doesn't document a reliable bulk-transaction-listing endpoint
for third-party integrations (that's a dashboard-only view) — polling each
locally-known transaction's own status endpoint is the documented, supported
way to ask "is Wompi's state the same as mine?" for exactly the transactions
this app cares about. A payment already in a terminal state we haven't been
told to distrust doesn't need re-checking, so this only looks at payments
that are `pending`/`processing` locally, or that were `approved`/`declined`
within the lookback window (catching a webhook that silently failed to
arrive at all — the one failure mode idempotent webhook handling can't
self-heal).

Usage (needs WOMPI_PRIVATE_KEY configured; a no-op without it):

    uv run python scripts/reconcile_wompi.py [--hours 24]

Exit code is 1 if any mismatch was found (so a cron/CI wrapper can alert on
a non-zero exit), 0 otherwise -- including "nothing to check".
"""

from __future__ import annotations

import argparse
import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from app.core.database import get_sessionmaker
from app.models.ledger import Payment, PaymentProvider, PaymentStatus
from app.services.payments.wompi import WompiApiError, WompiGateway, WompiNotConfiguredError

logger = logging.getLogger("reconcile_wompi")

_RECHECK_TERMINAL_STATUSES = {PaymentStatus.approved, PaymentStatus.declined}


@dataclass(frozen=True)
class Mismatch:
    payment_id: str
    reference: str
    local_status: PaymentStatus
    wompi_status: PaymentStatus


async def find_mismatches(hours: int = 24) -> list[Mismatch]:
    gateway = WompiGateway()
    session_maker = get_sessionmaker()
    cutoff = datetime.now(UTC) - timedelta(hours=hours)
    mismatches: list[Mismatch] = []

    async with session_maker() as session:
        payments = (
            await session.scalars(
                select(Payment).where(Payment.provider == PaymentProvider.wompi)
            )
        ).all()

        for payment in payments:
            # SQLite (this app's test DB) returns a naive datetime even for a
            # `DateTime(timezone=True)` column; Postgres (real deployments)
            # returns an aware one. Normalize to aware-UTC before comparing
            # either way, rather than assuming the DB's behavior.
            created_at = payment.created_at
            if created_at is not None and created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=UTC)
            needs_check = payment.status not in _RECHECK_TERMINAL_STATUSES or (
                created_at is not None and created_at >= cutoff
            )
            if not needs_check or payment.provider_ref is None:
                continue
            try:
                wompi_status = await gateway.get_status(session, payment)
            except WompiNotConfiguredError:
                logger.warning("WOMPI_PRIVATE_KEY not configured -- nothing to reconcile")
                return []
            except WompiApiError:
                logger.exception("Wompi status lookup failed for payment %s", payment.id)
                continue
            if wompi_status != payment.status:
                mismatches.append(
                    Mismatch(
                        payment_id=str(payment.id),
                        reference=payment.reference,
                        local_status=payment.status,
                        wompi_status=wompi_status,
                    )
                )
    return mismatches


async def main_async(hours: int) -> int:
    mismatches = await find_mismatches(hours=hours)
    if not mismatches:
        logger.info("Reconciliation clean: no mismatches in the last %d hours", hours)
        return 0
    for m in mismatches:
        logger.error(
            "MISMATCH payment=%s reference=%s local=%s wompi=%s",
            m.payment_id,
            m.reference,
            m.local_status.value,
            m.wompi_status.value,
        )
    return 1


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--hours", type=int, default=24, help="lookback window for terminal recheck"
    )
    args = parser.parse_args()
    exit_code = asyncio.run(main_async(args.hours))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
