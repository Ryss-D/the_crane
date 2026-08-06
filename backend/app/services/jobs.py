"""Job state machine service (JOB-3) + completion accrual (LED-1, accrual half).

One allowed-transitions map governs the lifecycle (PLAN §2.3):

    requested -> matching -> assigned -> en_route_pickup -> arrived_pickup
        -> loading -> in_transit -> delivered -> completed

plus terminal `cancelled` / `no_drivers`. Every transition stamps its timestamp
column, optionally persists a driver location snapshot, and emits through an
injectable async event hook — TRK-3 overrides `get_job_event_hook` to broadcast
on the job's WS channel + FCM; the default is a no-op.

Cancellation rules: the customer may cancel while requested/matching/assigned
(free until `assigned` + a config-driven grace period; afterwards the cancel is
recorded as `customer_after_assign` — the fee policy lands later). A driver
cancel returns the job to `matching` and clears the driver so dispatch (DSP-2)
can re-offer it.
"""

from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver import DriverProfile, DriverStatus
from app.models.job import DriverLocationSnapshot, Job, JobStatus
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.user import User
from app.services.config import RedisLike, get_config
from app.services.payments.base import PaymentGateway
from app.services.payments.cash import CashGateway


class JobTransitionError(Exception):
    """Illegal state-machine move — the API layer maps this to HTTP 409."""


class JobAccessError(Exception):
    """Actor may not act on this job — the API layer maps this to HTTP 403."""


JobEventHook = Callable[[Job, JobStatus, JobStatus], Awaitable[None]]


async def _noop_event_hook(job: Job, old: JobStatus, new: JobStatus) -> None:
    return None


def get_job_event_hook() -> JobEventHook:
    """Dependency returning the transition event hook.

    TRK-3 overrides this to broadcast job events over WebSocket + FCM; until
    then transitions are silent.
    """
    return _noop_event_hook


_cash_gateway = CashGateway()


def get_payment_gateway() -> PaymentGateway:
    """Dependency returning the gateway completion accrual settles through.

    Cash for the whole MVP; PAY-2 overrides this per-job once Wompi lands
    (e.g. picking cash vs. wompi from the job's payment_method).
    """
    return _cash_gateway


ALLOWED_TRANSITIONS: dict[JobStatus, frozenset[JobStatus]] = {
    JobStatus.requested: frozenset({JobStatus.matching, JobStatus.cancelled}),
    JobStatus.matching: frozenset({JobStatus.assigned, JobStatus.no_drivers, JobStatus.cancelled}),
    # `-> matching` edges below are driver cancellations: the job returns to the pool.
    JobStatus.assigned: frozenset(
        {JobStatus.en_route_pickup, JobStatus.matching, JobStatus.cancelled}
    ),
    JobStatus.en_route_pickup: frozenset({JobStatus.arrived_pickup, JobStatus.matching}),
    JobStatus.arrived_pickup: frozenset({JobStatus.loading, JobStatus.matching}),
    JobStatus.loading: frozenset({JobStatus.in_transit}),
    JobStatus.in_transit: frozenset({JobStatus.delivered}),
    JobStatus.delivered: frozenset({JobStatus.completed}),
    JobStatus.completed: frozenset(),
    JobStatus.cancelled: frozenset(),
    # DSP-5: customer retry re-enters the pool (dispatch.retry_dispatch drives this).
    JobStatus.no_drivers: frozenset({JobStatus.matching}),
}

# Statuses the assigned driver may set through POST /v1/jobs/{id}/status (JOB-6).
# `completed` is customer-only (confirm-delivery); dispatch owns matching/assigned.
DRIVER_PROGRESS_STATUSES = frozenset(
    {
        JobStatus.en_route_pickup,
        JobStatus.arrived_pickup,
        JobStatus.loading,
        JobStatus.in_transit,
        JobStatus.delivered,
    }
)

CUSTOMER_CANCELLABLE = frozenset({JobStatus.requested, JobStatus.matching, JobStatus.assigned})
DRIVER_CANCELLABLE = frozenset(
    {JobStatus.assigned, JobStatus.en_route_pickup, JobStatus.arrived_pickup}
)

_TIMESTAMP_COLUMNS: dict[JobStatus, str] = {
    JobStatus.assigned: "assigned_at",
    JobStatus.in_transit: "picked_up_at",
    JobStatus.completed: "completed_at",
    JobStatus.cancelled: "cancelled_at",
}

# Fallback when dispatch config lacks `cancel_grace_seconds`.
DEFAULT_CANCEL_GRACE_SECONDS = 60

# Statuses that end a driver's engagement with a job: they stop being "on_job" and
# become available for the next dispatch. `matching` here means the bail edge (old
# was NOT requested — see the check in transition()), not the initial dispatch entry.
RELEASES_DRIVER = frozenset({JobStatus.completed, JobStatus.cancelled, JobStatus.matching})


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _as_aware(dt: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC (all stamps are UTC)."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


async def transition(
    session: AsyncSession,
    job: Job,
    new_status: JobStatus,
    *,
    actor: User | None = None,
    lat: float | None = None,
    lng: float | None = None,
    event_hook: JobEventHook | None = None,
    cancel_reason: str | None = None,
) -> Job:
    """Move `job` to `new_status`: validate, stamp, snapshot, commit, emit.

    Raises JobTransitionError (409 at the API layer) on an illegal move. When
    lat/lng are given and a driver is attached, a driver_location_snapshot row
    is written in the same commit (dispute/audit trail).
    """
    old = job.status
    if new_status not in ALLOWED_TRANSITIONS.get(old, frozenset()):
        raise JobTransitionError(f"Illegal transition {old.value} -> {new_status.value}")

    if lat is not None and lng is not None and job.driver_id is not None:
        session.add(
            DriverLocationSnapshot(
                job_id=job.id,
                driver_id=job.driver_id,
                lat=lat,
                lng=lng,
                job_status=new_status,
            )
        )

    if job.driver_id is not None and new_status in RELEASES_DRIVER:
        # Job is leaving this driver's hands (bail, cancel, or completion): they
        # stop being "on_job" so dispatch can offer them the next one. (When
        # new_status is `matching` via the requested->matching initial entry,
        # job.driver_id is always None here, so that case never reaches this
        # branch — only the driver-bail edge does.) Without this a driver's
        # first job would strand them on_job forever.
        driver_profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == job.driver_id)
        )
        if driver_profile is not None and driver_profile.status is DriverStatus.on_job:
            driver_profile.status = DriverStatus.available
            session.add(driver_profile)

    if new_status is JobStatus.matching and old is not JobStatus.requested:
        # Driver bailed: release the job back to the pool.
        job.driver_id = None
        # DSP-2 hook point: the dispatch service re-runs its sequential-offer
        # loop from here (dispatch.request_drivers(job)) once it lands.

    if cancel_reason is not None:
        job.cancel_reason = cancel_reason
    column = _TIMESTAMP_COLUMNS.get(new_status)
    if column is not None:
        setattr(job, column, _utcnow())
    job.status = new_status

    await session.commit()
    await (event_hook or _noop_event_hook)(job, old, new_status)
    return job


async def cancel_job(
    session: AsyncSession,
    redis: RedisLike,
    job: Job,
    *,
    actor: User,
    event_hook: JobEventHook | None = None,
) -> Job:
    """Cancel per JOB-3 rules: customer -> cancelled, assigned driver -> back to matching."""
    if actor.id == job.customer_id:
        return await _customer_cancel(session, redis, job, actor=actor, event_hook=event_hook)
    if job.driver_id is not None and actor.id == job.driver_id:
        return await _driver_cancel(session, job, actor=actor, event_hook=event_hook)
    raise JobAccessError("Only the job's customer or assigned driver may cancel it")


async def _customer_cancel(
    session: AsyncSession,
    redis: RedisLike,
    job: Job,
    *,
    actor: User,
    event_hook: JobEventHook | None,
) -> Job:
    if job.status not in CUSTOMER_CANCELLABLE:
        raise JobTransitionError(f"Customer cannot cancel a job in status {job.status.value}")

    reason = "customer"
    if job.status is JobStatus.assigned:
        dispatch_config = await get_config(session, redis, "dispatch") or {}
        grace_seconds = dispatch_config.get("cancel_grace_seconds", DEFAULT_CANCEL_GRACE_SECONDS)
        within_grace = (
            job.assigned_at is not None
            and (_utcnow() - _as_aware(job.assigned_at)).total_seconds() <= grace_seconds
        )
        if not within_grace:
            # Fee policy for late cancels lands later; for now only the reason differs.
            reason = "customer_after_assign"
    return await transition(
        session,
        job,
        JobStatus.cancelled,
        actor=actor,
        cancel_reason=reason,
        event_hook=event_hook,
    )


async def _driver_cancel(
    session: AsyncSession,
    job: Job,
    *,
    actor: User,
    event_hook: JobEventHook | None,
) -> Job:
    if job.status not in DRIVER_CANCELLABLE:
        raise JobTransitionError(f"Driver cannot cancel a job in status {job.status.value}")
    # transition() clears driver_id on the -> matching edge (re-dispatch hook there).
    return await transition(session, job, JobStatus.matching, actor=actor, event_hook=event_hook)


async def confirm_delivery(
    session: AsyncSession,
    job: Job,
    *,
    actor: User,
    event_hook: JobEventHook | None = None,
    payment_gateway: PaymentGateway | None = None,
) -> Job:
    """CUS-5: the customer confirms delivery + cash handover -> completed + accrual.

    Idempotent: retrying after a successful confirm returns the completed job
    without duplicating the payment/ledger rows (unique `payments.reference`,
    enforced by the gateway's create_intent — see _accrue_completion).
    """
    if actor.id != job.customer_id:
        raise JobAccessError("Only the job's customer may confirm delivery")
    if job.status is JobStatus.completed:
        return job  # retry after success — accrual already written
    if job.status is not JobStatus.delivered:
        raise JobTransitionError(
            f"Delivery can only be confirmed from delivered (job is {job.status.value})"
        )

    if job.final_price is None:
        job.final_price = job.quoted_price  # final price = quote, no surge in MVP
    await _accrue_completion(session, job, payment_gateway or get_payment_gateway())
    # Accrual rows and the status flip share transition()'s single commit.
    return await transition(session, job, JobStatus.completed, actor=actor, event_hook=event_hook)


async def _accrue_completion(session: AsyncSession, job: Job, gateway: PaymentGateway) -> None:
    """LED-1 accrual: payment (via `gateway`) + driver ledger earning, exactly
    once per job — `create_intent`'s `created` flag is the idempotency check.

    Commission comes from the job's config_snapshot (never current config), so a
    rate change after creation cannot rewrite history. Which gateway settled the
    fare is the gateway's concern; commission/ledger accounting is platform
    business logic that stays here regardless of gateway (cash today, Wompi later).
    """
    _payment, created = await gateway.create_intent(session, job)
    if not created:
        return  # retry — payment + ledger already written

    amount = int(job.final_price)
    commission = commission_for_fare(job, amount)
    session.add(
        DriverLedgerEntry(
            driver_id=job.driver_id,
            job_id=job.id,
            gross=amount,
            commission=commission,
            net=amount - commission,
            entry_type=LedgerEntryType.earning,
        )
    )


def commission_for_fare(job: Job, fare: int) -> int:
    """COP commission on `fare` per the job's snapshot: percent -> rate x fare, flat ->
    amount. Shared by completion accrual (`fare` = final_price) and the DRV-2 offer
    preview (`fare` = quoted_price, since final_price is null until completion)."""
    commission_config = (job.config_snapshot or {}).get("commission") or {}
    vehicle_type = job.vehicle_type.value
    mode = commission_config.get("mode")
    if mode == "percent":
        rate = float((commission_config.get("rate") or {}).get(vehicle_type, 0))
        return round(fare * rate)
    if mode == "flat":
        return int((commission_config.get("amount") or {}).get(vehicle_type, 0))
    return 0  # defensive: JOB-5 jobs always carry a snapshot
