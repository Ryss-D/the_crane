"""ADM-2 tests: require_admin enforcement, config CRUD + audit, driver filters/verify/
block/unblock (incl. its effect on PATCH /v1/drivers/me/status), jobs list/filter/
detail (offer trail + config_snapshot), admin cancel from various statuses, and
ledger list + settle."""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.driver import DriverProfile, DriverStatus
from app.models.job import DriverLocationSnapshot, JobOffer, JobStatus, OfferResponse
from app.models.ledger import DriverLedgerEntry, LedgerEntryType
from app.models.user import User
from app.services.ledger import driver_owed_balance
from tests.conftest import FakeRedis, make_available_driver, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}
AUTH_ADMIN = {"Authorization": "Bearer admin-token"}


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    admin_user: User,
) -> dict[str, dict[str, Any]]:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["admin-token"] = {"uid": admin_user.firebase_uid}
    return verified_tokens


# ---- require_admin enforcement -------------------------------------------------


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("GET", "/v1/admin/config"),
        ("PUT", "/v1/admin/config/somekey"),
        ("GET", "/v1/admin/drivers"),
        ("POST", f"/v1/admin/drivers/{uuid.uuid4()}/verify"),
        ("POST", f"/v1/admin/drivers/{uuid.uuid4()}/block"),
        ("POST", f"/v1/admin/drivers/{uuid.uuid4()}/unblock"),
        ("GET", "/v1/admin/jobs"),
        ("GET", f"/v1/admin/jobs/{uuid.uuid4()}"),
        ("POST", f"/v1/admin/jobs/{uuid.uuid4()}/cancel"),
        ("GET", "/v1/admin/ledger"),
        ("GET", f"/v1/admin/ledger/{uuid.uuid4()}/entries"),
        ("POST", f"/v1/admin/ledger/{uuid.uuid4()}/settle"),
    ],
)
async def test_admin_routes_reject_non_admin(
    client: AsyncClient, tokens: dict, method: str, path: str
) -> None:
    response = await client.request(
        method,
        path,
        headers=AUTH_CUSTOMER,
        json={"value": 1} if method in ("PUT", "POST") else None,
    )
    assert response.status_code == 403


# ---- Config ---------------------------------------------------------------------


async def test_config_get_shows_audit_trail(
    client: AsyncClient, tokens: dict, seeded_config: dict[str, Any]
) -> None:
    response = await client.get("/v1/admin/config", headers=AUTH_ADMIN)
    assert response.status_code == 200
    by_key = {row["key"]: row for row in response.json()}
    assert "pricing" in by_key
    assert len(by_key["pricing"]["audit"]) == 1  # one seed write -> one audit row
    assert by_key["pricing"]["audit"][0]["new_value"] == seeded_config["pricing"]


async def test_config_put_updates_value_and_appends_audit(
    client: AsyncClient, tokens: dict, admin_user: User, seeded_config: dict[str, Any]
) -> None:
    new_value = {"period": "daily", "balance_cap": 50000}
    response = await client.put(
        "/v1/admin/config/settlement", headers=AUTH_ADMIN, json={"value": new_value}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["value"] == new_value
    assert body["updated_by"] == str(admin_user.id)
    assert len(body["audit"]) == 2  # seed write + this update
    # SQLite's CURRENT_TIMESTAMP has second resolution, so within a single fast test
    # the seed write and this update can tie — assert membership, not index order.
    audit_values = [entry["new_value"] for entry in body["audit"]]
    assert new_value in audit_values
    assert seeded_config["settlement"] in audit_values


async def test_config_put_upserts_unknown_key(
    client: AsyncClient, tokens: dict, seeded_config: dict[str, Any]
) -> None:
    response = await client.put(
        "/v1/admin/config/brand_new_key", headers=AUTH_ADMIN, json={"value": {"flag": True}}
    )
    assert response.status_code == 200
    assert response.json()["value"] == {"flag": True}

    listed = await client.get("/v1/admin/config", headers=AUTH_ADMIN)
    keys = {row["key"] for row in listed.json()}
    assert "brand_new_key" in keys


# ---- Drivers ----------------------------------------------------------------------


async def test_list_drivers_filters(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    available = await make_available_driver(
        session_maker, fake_redis, firebase_uid="drv-available", verified=True
    )
    offline_unverified = await make_available_driver(
        session_maker,
        fake_redis,
        firebase_uid="drv-offline",
        verified=False,
        status=DriverStatus.offline,
    )

    response = await client.get("/v1/admin/drivers", headers=AUTH_ADMIN)
    assert response.status_code == 200
    body = response.json()
    ids = {row["user_id"] for row in body["items"]}
    assert str(available.id) in ids
    assert str(offline_unverified.id) in ids
    assert body["total"] >= 2

    verified_only = await client.get(
        "/v1/admin/drivers", headers=AUTH_ADMIN, params={"verified": "true"}
    )
    verified_ids = {row["user_id"] for row in verified_only.json()["items"]}
    assert str(available.id) in verified_ids
    assert str(offline_unverified.id) not in verified_ids

    status_only = await client.get(
        "/v1/admin/drivers", headers=AUTH_ADMIN, params={"status": "offline"}
    )
    status_ids = {row["user_id"] for row in status_only.json()["items"]}
    assert str(offline_unverified.id) in status_ids
    assert str(available.id) not in status_ids

    # owed_balance is present and reflects driver_owed_balance
    row = next(r for r in body["items"] if r["user_id"] == str(available.id))
    assert row["owed_balance"] == 0
    # Document URLs are exposed (ADM-4's admin document-viewer needs them);
    # the seeded driver has neither uploaded, so both are null, not absent.
    assert "license_url" in row
    assert row["license_url"] is None
    assert row["truck_photo_url"] is None


async def test_verify_driver(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    driver = await make_available_driver(
        session_maker,
        fake_redis,
        firebase_uid="drv-unverified",
        verified=False,
        status=DriverStatus.offline,
    )
    response = await client.post(f"/v1/admin/drivers/{driver.id}/verify", headers=AUTH_ADMIN)
    assert response.status_code == 200
    assert response.json()["verified"] is True

    async with session_maker() as session:
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == driver.id)
        )
        assert profile is not None
        assert profile.verified is True


async def test_block_then_unblock_driver_gates_availability(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    driver = await make_available_driver(
        session_maker,
        fake_redis,
        firebase_uid="drv-blockme",
        verified=True,
        status=DriverStatus.offline,
    )
    driver_headers = {"Authorization": "Bearer drv-blockme-token"}
    verified_tokens["drv-blockme-token"] = {"uid": driver.firebase_uid}

    block_resp = await client.post(f"/v1/admin/drivers/{driver.id}/block", headers=AUTH_ADMIN)
    assert block_resp.status_code == 200
    assert block_resp.json()["status"] == "blocked"

    denied = await client.patch(
        "/v1/drivers/me/status",
        headers=driver_headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert denied.status_code == 403

    unblock_resp = await client.post(f"/v1/admin/drivers/{driver.id}/unblock", headers=AUTH_ADMIN)
    assert unblock_resp.status_code == 200
    assert unblock_resp.json()["status"] == "offline"

    allowed = await client.patch(
        "/v1/drivers/me/status",
        headers=driver_headers,
        json={"status": "available", "lat": 6.2442, "lng": -75.5812},
    )
    assert allowed.status_code == 200
    assert allowed.json()["status"] == "available"


# ---- Jobs -------------------------------------------------------------------------


async def test_list_jobs_filters_by_status_newest_first(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    older = await make_job(
        session_maker,
        customer_user,
        status=JobStatus.requested,
        requested_at=datetime.now(UTC) - timedelta(hours=1),
    )
    newer = await make_job(session_maker, customer_user, status=JobStatus.requested)
    await make_job(session_maker, customer_user, status=JobStatus.completed)

    response = await client.get(
        "/v1/admin/jobs", headers=AUTH_ADMIN, params={"status": "requested"}
    )
    assert response.status_code == 200
    body = response.json()
    ids = [item["id"] for item in body["items"]]
    assert str(newer.id) in ids
    assert str(older.id) in ids
    assert ids.index(str(newer.id)) < ids.index(str(older.id))  # newest first
    assert all(item["status"] == "requested" for item in body["items"])


async def test_list_jobs_includes_customer_and_driver_names(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    """Regression: JobRead only has customer_id/driver_id (raw UUIDs) — the
    admin list must join in names, batched (one query per page, not per job)."""
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.assigned
    )
    unassigned = await make_job(session_maker, customer_user, status=JobStatus.matching)

    response = await client.get("/v1/admin/jobs", headers=AUTH_ADMIN)
    assert response.status_code == 200
    by_id = {item["id"]: item for item in response.json()["items"]}

    assert by_id[str(job.id)]["customer_name"] == customer_user.name
    assert by_id[str(job.id)]["customer_phone"] == customer_user.phone
    assert by_id[str(job.id)]["driver_name"] == driver_user.name

    assert by_id[str(unassigned.id)]["customer_name"] == customer_user.name
    assert by_id[str(unassigned.id)]["driver_id"] is None
    assert by_id[str(unassigned.id)]["driver_name"] is None


async def test_get_job_admin_detail_includes_offers_and_snapshots(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    job = await make_job(
        session_maker,
        customer_user,
        driver=driver_user,
        status=JobStatus.assigned,
        config_snapshot={"pricing": {"car": {"base": 1}}, "commission": {"mode": "flat"}},
    )
    async with session_maker() as session:
        session.add(
            JobOffer(job_id=job.id, driver_id=driver_user.id, response=OfferResponse.accepted)
        )
        session.add(
            DriverLocationSnapshot(
                job_id=job.id,
                driver_id=driver_user.id,
                lat=6.24,
                lng=-75.58,
                job_status=JobStatus.assigned,
            )
        )
        await session.commit()

    response = await client.get(f"/v1/admin/jobs/{job.id}", headers=AUTH_ADMIN)
    assert response.status_code == 200
    body = response.json()
    assert body["customer_name"] == customer_user.name
    assert body["driver_name"] == driver_user.name
    assert len(body["offers"]) == 1
    assert body["offers"][0]["driver_id"] == str(driver_user.id)
    assert body["offers"][0]["driver_name"] == driver_user.name
    assert len(body["location_snapshots"]) == 1
    assert body["config_snapshot"]["commission"]["mode"] == "flat"

    missing = await client.get(f"/v1/admin/jobs/{uuid.uuid4()}", headers=AUTH_ADMIN)
    assert missing.status_code == 404


@pytest.mark.parametrize(
    "status_value",
    [
        JobStatus.requested,
        JobStatus.matching,
        JobStatus.assigned,
        JobStatus.en_route_pickup,
        JobStatus.arrived_pickup,
        JobStatus.loading,
        JobStatus.in_transit,
        JobStatus.delivered,
        JobStatus.no_drivers,
    ],
)
async def test_admin_cancel_from_any_non_terminal_status(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    status_value: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, driver=driver_user, status=status_value)
    response = await client.post(f"/v1/admin/jobs/{job.id}/cancel", headers=AUTH_ADMIN)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "cancelled"
    assert body["cancel_reason"] == "admin"
    assert body["cancelled_at"] is not None


async def test_admin_cancel_releases_driver_from_on_job(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    driver_user: User,
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    """Regression: the admin-cancel path bypasses the state machine for
    mid-flight statuses (see _admin_cancel_job's docstring) and must mirror
    its driver-release side effect manually — otherwise an admin-cancelled
    mid-flight job strands its driver on_job forever."""
    async with session_maker() as session:
        session.add(
            DriverProfile(user_id=driver_user.id, status=DriverStatus.on_job, verified=True)
        )
        await session.commit()
    job = await make_job(
        session_maker, customer_user, driver=driver_user, status=JobStatus.en_route_pickup
    )
    response = await client.post(f"/v1/admin/jobs/{job.id}/cancel", headers=AUTH_ADMIN)
    assert response.status_code == 200
    async with session_maker() as session:
        profile = await session.scalar(
            select(DriverProfile).where(DriverProfile.user_id == driver_user.id)
        )
        assert profile is not None
        assert profile.status is DriverStatus.available


@pytest.mark.parametrize("status_value", [JobStatus.completed, JobStatus.cancelled])
async def test_admin_cancel_terminal_status_is_409(
    client: AsyncClient,
    tokens: dict,
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    status_value: JobStatus,
) -> None:
    job = await make_job(session_maker, customer_user, status=status_value)
    response = await client.post(f"/v1/admin/jobs/{job.id}/cancel", headers=AUTH_ADMIN)
    assert response.status_code == 409


# ---- Ledger -------------------------------------------------------------------------


async def test_ledger_list_and_settle_reduces_balance(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="drv-ledger", status=DriverStatus.offline
    )
    async with session_maker() as session:
        session.add(
            DriverLedgerEntry(
                driver_id=driver.id,
                job_id=None,
                gross=100000,
                commission=15000,
                net=85000,
                entry_type=LedgerEntryType.earning,
            )
        )
        await session.commit()

    async with session_maker() as session:
        before = await driver_owed_balance(session, driver.id)
    assert before == 15000

    listed = await client.get("/v1/admin/ledger", headers=AUTH_ADMIN)
    assert listed.status_code == 200
    row = next(r for r in listed.json()["items"] if r["driver_id"] == str(driver.id))
    assert row["owed_balance"] == 15000

    settle = await client.post(
        f"/v1/admin/ledger/{driver.id}/settle",
        headers=AUTH_ADMIN,
        json={"amount": 10000, "note": "partial cash settlement"},
    )
    assert settle.status_code == 201
    settle_body = settle.json()
    assert settle_body["entry_type"] == "payout"
    assert settle_body["note"] == "partial cash settlement"

    async with session_maker() as session:
        after = await driver_owed_balance(session, driver.id)
    assert after == 5000

    async with session_maker() as session:
        rows = (
            await session.scalars(
                select(DriverLedgerEntry).where(
                    DriverLedgerEntry.driver_id == driver.id,
                    DriverLedgerEntry.entry_type == LedgerEntryType.payout,
                )
            )
        ).all()
        assert len(rows) == 1
        assert rows[0].note == "partial cash settlement"

    # ADM-6 drill-down: the earning row + the settlement just recorded.
    # (Not asserting order: sqlite's CURRENT_TIMESTAMP has 1s resolution, so
    # two commits in the same test can tie — see the config-audit note in
    # app/api/admin.py for the same caveat. Postgres in prod won't tie at
    # human-driven edit rates.)
    entries = await client.get(f"/v1/admin/ledger/{driver.id}/entries", headers=AUTH_ADMIN)
    assert entries.status_code == 200
    body = entries.json()
    assert body["total"] == 2
    assert {e["entry_type"] for e in body["items"]} == {"payout", "earning"}
    payout = next(e for e in body["items"] if e["entry_type"] == "payout")
    assert payout["net"] == 10000


async def test_ledger_entries_404_for_non_driver(
    client: AsyncClient, tokens: dict, customer_user: User
) -> None:
    response = await client.get(f"/v1/admin/ledger/{customer_user.id}/entries", headers=AUTH_ADMIN)
    assert response.status_code == 404


async def test_settle_rejects_non_positive_amount(
    client: AsyncClient,
    tokens: dict,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
) -> None:
    driver = await make_available_driver(
        session_maker, fake_redis, firebase_uid="drv-badamount", status=DriverStatus.offline
    )
    response = await client.post(
        f"/v1/admin/ledger/{driver.id}/settle", headers=AUTH_ADMIN, json={"amount": 0}
    )
    assert response.status_code == 422
