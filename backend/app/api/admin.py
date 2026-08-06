"""Admin API (ADM-2): runtime config, driver ops, job oversight, ledger/settlements.

Every route sits behind `require_admin` (see app/core/security.py's `AdminUser`).
Config reuses the existing service (app/services/config.py) so audited writes +
Redis-cache busting stay a single code path. Driver verify/block/unblock mirror the
conventions already exercised in tests/test_drivers_api.py (`verified` flipped
directly, `blocked` reusing DriverStatus from app/models/driver.py). Job listing
reuses JOB-5's JobRead/JobListResponse schemas (no ownership filter — admin sees
all). The admin cancel path is documented at `_admin_cancel_job` below: JOB-3's
state machine doesn't wire a `-> cancelled` edge from every non-terminal status, so
this route can't always go through `transition()` as-is.
"""

import uuid
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import AdminUser
from app.models.driver import DriverProfile, DriverStatus, Truck
from app.models.fleet import Fleet
from app.models.job import DriverLocationSnapshot, Job, JobOffer, JobStatus
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.platform_config import PlatformConfig, PlatformConfigAudit
from app.models.user import User, UserRole
from app.schemas.admin import (
    AdminDriverListResponse,
    AdminDriverRead,
    AdminJobListItem,
    AdminJobListResponse,
    AdminLedgerListResponse,
    AdminLedgerRead,
    ConfigAuditRead,
    ConfigRead,
    ConfigUpdate,
    DriverLedgerEntryListResponse,
    DriverLedgerEntryRead,
    DriverLocationSnapshotRead,
    JobAdminDetail,
    JobOfferRead,
    LedgerSettleRequest,
)
from app.schemas.driver import TruckRead
from app.schemas.fleet import (
    AdminFleetListItem,
    FleetBalanceRead,
    FleetMemberBalance,
    FleetSettlementEntry,
    FleetSettleRequest,
    FleetSettleResponse,
)
from app.schemas.job import JobRead
from app.services import dispatch
from app.services.config import RedisLike, set_config
from app.services.jobs import ALLOWED_TRANSITIONS, JobEventHook, get_job_event_hook, transition
from app.services.ledger import apportion, driver_owed_balance, fleet_member_balances

router = APIRouter(prefix="/admin", tags=["admin"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]
RedisDep = Annotated[RedisLike, Depends(get_redis)]
EventHookDep = Annotated[JobEventHook, Depends(get_job_event_hook)]

CONFIG_AUDIT_RECENT_LIMIT = 5
LOCATION_SNAPSHOT_RECENT_LIMIT = 20


def _utcnow() -> datetime:
    return datetime.now(UTC)


@router.get("/ping")
async def admin_ping(user: AdminUser) -> dict[str, str]:
    """Minimal admin-only route proving `require_admin`."""
    return {"status": "ok", "admin": user.firebase_uid}


# ---- Config (ADM-2 / ADM-3) --------------------------------------------------


async def _config_read(session: AsyncSession, row: PlatformConfig) -> ConfigRead:
    audit_rows = (
        await session.scalars(
            select(PlatformConfigAudit)
            .where(PlatformConfigAudit.key == row.key)
            .order_by(PlatformConfigAudit.changed_at.desc())
            .limit(CONFIG_AUDIT_RECENT_LIMIT)
        )
    ).all()
    return ConfigRead(
        key=row.key,
        value=row.value,
        updated_by=row.updated_by,
        updated_at=row.updated_at,
        audit=[ConfigAuditRead.model_validate(a) for a in audit_rows],
    )


@router.get("/config", response_model=list[ConfigRead])
async def list_config(admin: AdminUser, session: SessionDep) -> list[ConfigRead]:
    """All platform_config rows, each with its last 5 audit entries."""
    rows = (await session.scalars(select(PlatformConfig).order_by(PlatformConfig.key))).all()
    return [await _config_read(session, row) for row in rows]


@router.put("/config/{key}", response_model=ConfigRead)
async def update_config(
    key: str,
    body: ConfigUpdate,
    admin: AdminUser,
    session: SessionDep,
    redis: RedisDep,
) -> ConfigRead:
    """Upsert `key` (unknown keys are created, not 404ed) with the acting admin as
    `updated_by`; busts the Redis cache via the existing config service."""
    row = await set_config(session, redis, key, body.value, user=admin)
    return await _config_read(session, row)


# ---- Drivers (ADM-2 / ADM-4) --------------------------------------------------


async def _serialize_admin_driver(
    session: AsyncSession, profile: DriverProfile, user: User
) -> AdminDriverRead:
    truck = await session.scalar(select(Truck).where(Truck.driver_id == user.id))
    owed = await driver_owed_balance(session, user.id)
    return AdminDriverRead(
        user_id=user.id,
        name=user.name,
        phone=user.phone,
        email=user.email,
        status=profile.status,
        verified=profile.verified,
        rating_avg=float(profile.rating_avg) if profile.rating_avg is not None else None,
        truck=TruckRead.model_validate(truck) if truck is not None else None,
        owed_balance=owed,
        license_url=profile.license_url,
        truck_photo_url=profile.truck_photo_url,
    )


async def _get_driver_or_404(
    session: AsyncSession, driver_id: uuid.UUID
) -> tuple[DriverProfile, User]:
    row = (
        await session.execute(
            select(DriverProfile, User)
            .join(User, User.id == DriverProfile.user_id)
            .where(DriverProfile.user_id == driver_id)
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found")
    profile, user = row
    return profile, user


@router.get("/drivers", response_model=AdminDriverListResponse)
async def list_drivers(
    admin: AdminUser,
    session: SessionDep,
    verified: bool | None = None,
    driver_status: Annotated[DriverStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AdminDriverListResponse:
    stmt = select(DriverProfile, User).join(User, User.id == DriverProfile.user_id)
    if verified is not None:
        stmt = stmt.where(DriverProfile.verified == verified)
    if driver_status is not None:
        stmt = stmt.where(DriverProfile.status == driver_status)

    total = await session.scalar(select(func.count()).select_from(stmt.subquery()))
    rows = (
        await session.execute(stmt.order_by(User.created_at.desc()).limit(limit).offset(offset))
    ).all()
    items = [await _serialize_admin_driver(session, profile, user) for profile, user in rows]
    return AdminDriverListResponse(items=items, total=total or 0, limit=limit, offset=offset)


@router.post("/drivers/{driver_id}/verify", response_model=AdminDriverRead)
async def verify_driver(
    driver_id: uuid.UUID, admin: AdminUser, session: SessionDep
) -> AdminDriverRead:
    """Flips driver_profiles.verified = true (mirrors how tests/test_drivers_api.py's
    `_register_and_verify` helper sets it directly today)."""
    profile, user = await _get_driver_or_404(session, driver_id)
    profile.verified = True
    await session.commit()
    await session.refresh(profile)
    return await _serialize_admin_driver(session, profile, user)


@router.post("/drivers/{driver_id}/block", response_model=AdminDriverRead)
async def block_driver(
    driver_id: uuid.UUID, admin: AdminUser, session: SessionDep, redis: RedisDep
) -> AdminDriverRead:
    """Sets status -> blocked; a currently-available driver is pulled out of the
    Redis geo index too, so dispatch stops offering them jobs immediately."""
    profile, user = await _get_driver_or_404(session, driver_id)
    if profile.status is DriverStatus.available:
        truck = await session.scalar(select(Truck).where(Truck.driver_id == driver_id))
        if truck is not None:
            await dispatch.remove_driver_from_geo(redis, driver_id, truck.capacity)
    profile.status = DriverStatus.blocked
    await session.commit()
    await session.refresh(profile)
    return await _serialize_admin_driver(session, profile, user)


@router.post("/drivers/{driver_id}/unblock", response_model=AdminDriverRead)
async def unblock_driver(
    driver_id: uuid.UUID, admin: AdminUser, session: SessionDep
) -> AdminDriverRead:
    """Sets status -> offline; the driver must go available themselves afterward
    (PATCH /v1/drivers/me/status), same as any other offline driver."""
    profile, user = await _get_driver_or_404(session, driver_id)
    if profile.status is not DriverStatus.blocked:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Driver is not blocked")
    profile.status = DriverStatus.offline
    await session.commit()
    await session.refresh(profile)
    return await _serialize_admin_driver(session, profile, user)


# ---- Jobs (ADM-2 / ADM-5) ------------------------------------------------------


async def _get_job_or_404(session: AsyncSession, job_id: uuid.UUID) -> Job:
    job = await session.get(Job, job_id)
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    return job


async def _user_name_map(session: AsyncSession, user_ids: set[uuid.UUID]) -> dict[uuid.UUID, User]:
    """Batched lookup for the customer/driver names admin job views join in —
    one query per page/detail call instead of one per job (N+1)."""
    if not user_ids:
        return {}
    users = (await session.scalars(select(User).where(User.id.in_(user_ids)))).all()
    return {u.id: u for u in users}


def _job_list_item(job: Job, users: dict[uuid.UUID, User]) -> AdminJobListItem:
    customer = users.get(job.customer_id)
    driver = users.get(job.driver_id) if job.driver_id else None
    return AdminJobListItem(
        **JobRead.model_validate(job).model_dump(),
        customer_name=customer.name if customer else None,
        customer_phone=customer.phone if customer else None,
        driver_name=driver.name if driver else None,
    )


@router.get("/jobs", response_model=AdminJobListResponse)
async def list_jobs_admin(
    admin: AdminUser,
    session: SessionDep,
    job_status: Annotated[JobStatus | None, Query(alias="status")] = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> dict[str, Any]:
    """Every job, newest first — no ownership filter (admin sees all)."""
    stmt = select(Job)
    if job_status is not None:
        stmt = stmt.where(Job.status == job_status)
    if date_from is not None:
        stmt = stmt.where(Job.requested_at >= date_from)
    if date_to is not None:
        stmt = stmt.where(Job.requested_at <= date_to)

    total = await session.scalar(select(func.count()).select_from(stmt.subquery()))
    jobs = (
        await session.scalars(stmt.order_by(Job.requested_at.desc()).limit(limit).offset(offset))
    ).all()
    user_ids = {j.customer_id for j in jobs} | {j.driver_id for j in jobs if j.driver_id}
    users = await _user_name_map(session, user_ids)
    items = [_job_list_item(j, users) for j in jobs]
    return {"items": items, "total": total or 0, "limit": limit, "offset": offset}


@router.get("/jobs/{job_id}", response_model=JobAdminDetail)
async def get_job_admin(job_id: uuid.UUID, admin: AdminUser, session: SessionDep) -> JobAdminDetail:
    """Full detail: job fields + its job_offers trail + recent driver_location_
    snapshots + the config_snapshot it was created with (already a JobRead field)."""
    job = await _get_job_or_404(session, job_id)
    offers = (
        await session.scalars(
            select(JobOffer).where(JobOffer.job_id == job.id).order_by(JobOffer.offered_at)
        )
    ).all()
    snapshots = (
        await session.scalars(
            select(DriverLocationSnapshot)
            .where(DriverLocationSnapshot.job_id == job.id)
            .order_by(DriverLocationSnapshot.created_at.desc())
            .limit(LOCATION_SNAPSHOT_RECENT_LIMIT)
        )
    ).all()
    user_ids = {job.customer_id} | {o.driver_id for o in offers}
    if job.driver_id:
        user_ids.add(job.driver_id)
    users = await _user_name_map(session, user_ids)
    list_item = _job_list_item(job, users)
    return JobAdminDetail(
        **list_item.model_dump(),
        offers=[
            JobOfferRead(
                id=o.id,
                driver_id=o.driver_id,
                driver_name=users[o.driver_id].name if o.driver_id in users else None,
                offered_at=o.offered_at,
                responded_at=o.responded_at,
                response=o.response,
            )
            for o in offers
        ],
        location_snapshots=[DriverLocationSnapshotRead.model_validate(s) for s in snapshots],
    )


_ADMIN_CANCEL_BLOCKED = frozenset({JobStatus.completed, JobStatus.cancelled})


async def _admin_cancel_job(session: AsyncSession, job: Job, event_hook: JobEventHook) -> Job:
    """Admin override cancel: allowed from any non-terminal status, unlike the
    customer cancel in app/services/jobs.py (grace-period / cancellable-status rules).

    JOB-3's ALLOWED_TRANSITIONS only wires a `-> cancelled` edge for
    requested/matching/assigned (the customer-cancellable window) plus whatever
    dispatch itself allows; a mid-flight job (en_route_pickup..delivered) or a
    no_drivers job has NO `-> cancelled` edge at all, so reusing `transition()`
    unconditionally would 409 on exactly the stuck/abandoned jobs an admin most
    needs to kill. Where the state machine DOES already allow the edge, we still go
    through `transition()` (single source of truth, correct event-hook emission).
    Otherwise we replicate its relevant side effects directly — stamp
    cancelled_at/cancel_reason, commit, fire the event hook — deliberately bypassing
    ALLOWED_TRANSITIONS for this admin-only path.
    """
    old = job.status
    if old in _ADMIN_CANCEL_BLOCKED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot cancel a job in status {old.value}",
        )
    if JobStatus.cancelled in ALLOWED_TRANSITIONS.get(old, frozenset()):
        return await transition(
            session, job, JobStatus.cancelled, cancel_reason="admin", event_hook=event_hook
        )
    job.cancel_reason = "admin"
    job.cancelled_at = _utcnow()
    job.status = JobStatus.cancelled
    if job.driver_id is not None:
        # Mirrors transition()'s RELEASES_DRIVER handling, which this manual
        # path bypasses along with the rest of ALLOWED_TRANSITIONS.
        driver_profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == job.driver_id)
        )
        if driver_profile is not None and driver_profile.status is DriverStatus.on_job:
            driver_profile.status = DriverStatus.available
            session.add(driver_profile)
    await session.commit()
    await event_hook(job, old, JobStatus.cancelled)
    return job


@router.post("/jobs/{job_id}/cancel", response_model=JobRead)
async def cancel_job_admin(
    job_id: uuid.UUID, admin: AdminUser, session: SessionDep, event_hook: EventHookDep
) -> Job:
    job = await _get_job_or_404(session, job_id)
    return await _admin_cancel_job(session, job, event_hook)


# ---- Ledger (ADM-2 / ADM-6) -----------------------------------------------------


@router.get("/ledger", response_model=AdminLedgerListResponse)
async def list_ledger(
    admin: AdminUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AdminLedgerListResponse:
    """Owed balance per driver (app/services/ledger.py), paginated over drivers."""
    stmt = select(User).where(User.role == UserRole.driver)
    total = await session.scalar(select(func.count()).select_from(stmt.subquery()))
    users = (
        await session.scalars(stmt.order_by(User.created_at.desc()).limit(limit).offset(offset))
    ).all()
    items = [
        AdminLedgerRead(
            driver_id=user.id,
            name=user.name,
            owed_balance=await driver_owed_balance(session, user.id),
        )
        for user in users
    ]
    return AdminLedgerListResponse(items=items, total=total or 0, limit=limit, offset=offset)


@router.get("/ledger/{driver_id}/entries", response_model=DriverLedgerEntryListResponse)
async def list_driver_ledger_entries(
    driver_id: uuid.UUID,
    admin: AdminUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> DriverLedgerEntryListResponse:
    """Drill-down for one driver's balance (ADM-6): every earning/payout/
    adjustment row, newest first."""
    user = await session.get(User, driver_id)
    if user is None or user.role != UserRole.driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found")
    stmt = select(DriverLedgerEntry).where(DriverLedgerEntry.driver_id == driver_id)
    total = await session.scalar(select(func.count()).select_from(stmt.subquery()))
    entries = (
        await session.scalars(
            stmt.order_by(DriverLedgerEntry.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    items = [DriverLedgerEntryRead.model_validate(e) for e in entries]
    return DriverLedgerEntryListResponse(items=items, total=total or 0, limit=limit, offset=offset)


@router.post(
    "/ledger/{driver_id}/settle",
    response_model=DriverLedgerEntryRead,
    status_code=status.HTTP_201_CREATED,
)
async def settle_driver(
    driver_id: uuid.UUID,
    body: LedgerSettleRequest,
    admin: AdminUser,
    session: SessionDep,
) -> DriverLedgerEntryRead:
    """Writes a `payout` driver_ledger row, reducing the driver's owed balance by
    `amount` (driver_owed_balance subtracts payout/adjustment `net` from accrued
    earning commissions — see app/services/ledger.py's docstring)."""
    user = await session.get(User, driver_id)
    if user is None or user.role != UserRole.driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found")
    if body.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="amount must be positive"
        )
    entry = DriverLedgerEntry(
        driver_id=driver_id,
        job_id=None,
        gross=body.amount,
        commission=0,
        net=body.amount,
        entry_type=LedgerEntryType.payout,
        note=body.note,
    )
    session.add(entry)
    await session.commit()
    await session.refresh(entry)
    return DriverLedgerEntryRead.model_validate(entry)


# ---- Fleets (FLT-2) -------------------------------------------------------------


async def _get_fleet_or_404(session: AsyncSession, fleet_id: uuid.UUID) -> Fleet:
    fleet = await session.get(Fleet, fleet_id)
    if fleet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fleet not found")
    return fleet


@router.get("/fleets", response_model=list[AdminFleetListItem])
async def list_fleets(admin: AdminUser, session: SessionDep) -> list[AdminFleetListItem]:
    """All fleets on the platform (ADM-7) — no ownership filter, admin sees all, same
    convention as job listing. Unpaginated: fleets are expected to stay few for MVP
    scale, same assumption GET /v1/fleets/me's truck list already makes."""
    fleets = (await session.scalars(select(Fleet))).all()
    if not fleets:
        return []
    owners = {
        u.id: u
        for u in (
            await session.scalars(select(User).where(User.id.in_(f.owner_user_id for f in fleets)))
        )
    }
    truck_counts = dict(
        (
            await session.execute(
                select(Truck.fleet_id, func.count())
                .where(Truck.fleet_id.in_(f.id for f in fleets))
                .group_by(Truck.fleet_id)
            )
        ).all()
    )
    balances = {f.id: await fleet_member_balances(session, f.id) for f in fleets}
    return [
        AdminFleetListItem(
            id=f.id,
            owner_user_id=f.owner_user_id,
            owner_name=owners[f.owner_user_id].name if f.owner_user_id in owners else None,
            name=f.name,
            truck_count=truck_counts.get(f.id, 0),
            owed_balance=sum(balances[f.id].values()),
            created_at=f.created_at,
        )
        for f in fleets
    ]


@router.get("/fleets/{fleet_id}/balance", response_model=FleetBalanceRead)
async def get_fleet_balance(
    fleet_id: uuid.UUID, admin: AdminUser, session: SessionDep
) -> FleetBalanceRead:
    """Consolidated owed balance across the fleet's member drivers, same rollup the
    fleet owner sees at GET /v1/fleets/me/balance (app/services/ledger.py)."""
    fleet = await _get_fleet_or_404(session, fleet_id)
    balances = await fleet_member_balances(session, fleet.id)
    users = (
        {u.id: u for u in (await session.scalars(select(User).where(User.id.in_(balances))))}
        if balances
        else {}
    )
    members = [
        FleetMemberBalance(
            driver_id=driver_id,
            name=users[driver_id].name if driver_id in users else None,
            owed_balance=owed,
        )
        for driver_id, owed in balances.items()
    ]
    return FleetBalanceRead(fleet_id=fleet.id, owed_balance=sum(balances.values()), members=members)


@router.post(
    "/fleets/{fleet_id}/settle",
    response_model=FleetSettleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def settle_fleet(
    fleet_id: uuid.UUID,
    body: FleetSettleRequest,
    admin: AdminUser,
    session: SessionDep,
) -> FleetSettleResponse:
    """Records ONE settlement for the whole fleet, apportioned across its member
    drivers' ledgers (`app/services/ledger.py`'s `apportion` — proportional to each
    driver's current owed balance, largest-remainder rounded so the per-driver
    payout rows sum to exactly `amount`). Each driver still gets their own `payout`
    driver_ledger row (same shape LED-4's per-driver settle writes) so
    driver_owed_balance and GET /v1/drivers/me/balance need no special-casing —
    a fleet settlement just looks like several ordinary settlements that happened
    to land at once, which is also why one settlement unblocks every capped member
    (DSP-1's balance-cap gate reads the fleet total via fleet_owed_balance)."""
    fleet = await _get_fleet_or_404(session, fleet_id)
    if body.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="amount must be positive"
        )
    balances = await fleet_member_balances(session, fleet.id)
    if not balances:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Fleet has no drivers to settle"
        )
    driver_ids = list(balances.keys())
    shares = apportion(body.amount, [balances[d] for d in driver_ids])

    entries: list[FleetSettlementEntry] = []
    for driver_id, share in zip(driver_ids, shares, strict=True):
        entry_id = uuid.uuid4()
        session.add(
            DriverLedgerEntry(
                id=entry_id,
                driver_id=driver_id,
                job_id=None,
                gross=share,
                commission=0,
                net=share,
                entry_type=LedgerEntryType.payout,
                note=body.note,
            )
        )
        entries.append(
            FleetSettlementEntry(driver_id=driver_id, ledger_entry_id=entry_id, amount=share)
        )
    await session.commit()
    return FleetSettleResponse(fleet_id=fleet.id, total_amount=body.amount, entries=entries)
