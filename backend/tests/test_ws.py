"""TRK-1/2/3/6 tests: WS auth, job/track subscriptions, job_event/driver_location/
job_offer delivery, and connection-registry cleanup.

Uses starlette's sync `TestClient(...).websocket_connect(...)` for the WS side (the
httpx AsyncClient this codebase otherwise uses has no WebSocket support) while still
driving job creation/transitions through the existing async `client` fixture — both
ultimately call into the same FastAPI `app` object with the same dependency overrides
(fake_redis, the per-test `connection_manager`), so a transition triggered via the
async client is visible to a WS connection opened via TestClient in the same test.
"""

import json
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.models.job import Job, JobStatus
from app.models.user import User
from app.services.connection_manager import ConnectionManager
from app.services.pricing import get_directions_client
from tests.conftest import FakeRedis, make_available_driver, make_job

AUTH_CUSTOMER = {"Authorization": "Bearer customer-token"}


class FixedDirections:
    async def road_distance_km(
        self, pickup: tuple[float, float], dropoff: tuple[float, float]
    ) -> float:
        return 10.0


def _job_body(quote_id: str) -> dict[str, Any]:
    return {
        "quote_id": quote_id,
        "vehicle_type": "car",
        "pickup": {"lat": 6.2442, "lng": -75.5812, "address": "Calle 10 # 43-12"},
        "dropoff": {"lat": 6.2000, "lng": -75.5700, "address": "Carrera 70 # 1-141"},
    }


async def _get_quote(app: FastAPI, client: AsyncClient) -> dict:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections()
    response = await client.post(
        "/v1/jobs/quote",
        headers=AUTH_CUSTOMER,
        json={
            "vehicle_type": "car",
            "pickup": {"lat": 6.2442, "lng": -75.5812},
            "dropoff": {"lat": 6.2000, "lng": -75.5700},
        },
    )
    assert response.status_code == 200
    return response.json()


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    driver_user: User,
) -> dict[str, dict[str, Any]]:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["driver-token"] = {"uid": driver_user.firebase_uid}
    return verified_tokens


# ---- connect / auth --------------------------------------------------------------


async def test_connect_with_valid_token_succeeds(app: FastAPI, tokens: Any) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token"):
        pass  # accept() succeeded, no WebSocketDisconnect raised


async def test_connect_with_invalid_token_closes_4001(app: FastAPI, tokens: Any) -> None:
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect("/v1/ws?token=not-a-real-token") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4001


async def test_connect_with_missing_token_closes_4001(app: FastAPI, tokens: Any) -> None:
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect("/v1/ws") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4001


# ---- subscribe / unsubscribe -------------------------------------------------------


async def test_subscribe_to_own_job_succeeds(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    connection_manager: ConnectionManager,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "subscribe", "job_id": str(job.id)})
        ack = ws.receive_json()
        assert ack == {"type": "subscribed", "job_id": str(job.id)}
        assert customer_user.id in connection_manager.local_job_subscribers(job.id)


async def test_subscribe_to_someone_elses_job_fails(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    driver_user: User,
    connection_manager: ConnectionManager,
) -> None:
    """customer-token's user is neither this job's customer nor its driver."""
    other_customer = driver_user  # any user that isn't the job's customer/driver works
    job = await make_job(session_maker, other_customer, status=JobStatus.matching)
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "subscribe", "job_id": str(job.id)})
        reply = ws.receive_json()
        assert reply["type"] == "error"
    assert connection_manager.local_job_subscribers(job.id) == set()


async def test_unsubscribe_removes_from_manager(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    connection_manager: ConnectionManager,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "subscribe", "job_id": str(job.id)})
        ws.receive_json()
        assert customer_user.id in connection_manager.local_job_subscribers(job.id)

        ws.send_json({"type": "unsubscribe", "job_id": str(job.id)})
        ack = ws.receive_json()
        assert ack == {"type": "unsubscribed", "job_id": str(job.id)}
        assert customer_user.id not in connection_manager.local_job_subscribers(job.id)


async def test_unknown_message_type_returns_error(app: FastAPI, tokens: Any) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "not_a_real_type"})
        reply = ws.receive_json()
        assert reply["type"] == "error"


async def test_malformed_json_returns_error(app: FastAPI, tokens: Any) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_text("{not valid json")
        reply = ws.receive_json()
        assert reply["type"] == "error"


# ---- job_event broadcasting (TRK-3) -------------------------------------------------


async def test_job_transition_broadcasts_job_event_to_subscribed_customer(
    app: FastAPI,
    client: AsyncClient,
    tokens: Any,
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    seeded_config: Any,
) -> None:
    driver = await make_available_driver(session_maker, fake_redis, firebase_uid="ws-driver")
    tokens["ws-driver-token"] = {"uid": driver.firebase_uid}

    quote = await _get_quote(app, client)
    create_resp = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    assert create_resp.status_code == 201
    job_id = create_resp.json()["id"]

    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "subscribe", "job_id": job_id})
        assert ws.receive_json() == {"type": "subscribed", "job_id": job_id}

        accept_resp = await client.post(
            f"/v1/jobs/{job_id}/accept", headers={"Authorization": "Bearer ws-driver-token"}
        )
        assert accept_resp.status_code == 200

        event = ws.receive_json()
        assert event["type"] == "job_event"
        assert event["job_id"] == job_id
        assert event["status"] == "assigned"
        assert event["old_status"] == "matching"
        assert event["driver_id"] == str(driver.id)


async def test_dispatch_offer_sends_job_offer_to_driver_ws(
    app: FastAPI,
    client: AsyncClient,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    seeded_config: Any,
) -> None:
    driver = await make_available_driver(session_maker, fake_redis, firebase_uid="offer-driver")
    tokens["offer-driver-token"] = {"uid": driver.firebase_uid}

    # Driver connects (and thus subscribes to its own user channel) BEFORE the job
    # exists — job_offer is a direct-to-user push, not tied to a job subscription.
    with TestClient(app).websocket_connect("/v1/ws?token=offer-driver-token") as driver_ws:
        quote = await _get_quote(app, client)
        create_resp = await client.post(
            "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
        )
        assert create_resp.status_code == 201

        offer = driver_ws.receive_json()
        assert offer["type"] == "job_offer"
        assert offer["job_id"] == create_resp.json()["id"]
        assert offer["vehicle_type"] == "car"


# ---- driver location pipeline (TRK-2) ------------------------------------------------


async def test_location_from_assigned_driver_relays_to_customer(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
    fake_redis: FakeRedis,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.en_route_pickup, driver=driver_user
    )

    tc = TestClient(app)
    with tc.websocket_connect("/v1/ws?token=customer-token") as customer_ws:
        customer_ws.send_json({"type": "subscribe", "job_id": str(job.id)})
        assert customer_ws.receive_json() == {"type": "subscribed", "job_id": str(job.id)}

        with tc.websocket_connect("/v1/ws?token=driver-token") as driver_ws:
            driver_ws.send_json(
                {"type": "location", "job_id": str(job.id), "lat": 6.25, "lng": -75.58}
            )

            event = customer_ws.receive_json()
            assert event == {
                "type": "driver_location",
                "job_id": str(job.id),
                "lat": 6.25,
                "lng": -75.58,
            }

    # TRK-2: Redis live key + a driver_location_snapshots row, both written.
    cached = json.loads(fake_redis.store[f"job:{job.id}:location"])
    assert cached == {"lat": 6.25, "lng": -75.58}

    from sqlalchemy import select

    from app.models.job import DriverLocationSnapshot

    async with session_maker() as session:
        snapshot = await session.scalar(
            select(DriverLocationSnapshot).where(DriverLocationSnapshot.job_id == job.id)
        )
    assert snapshot is not None
    assert snapshot.lat == 6.25
    assert snapshot.driver_id == driver_user.id


async def test_location_rejected_from_non_assigned_user(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    """customer_user is not this job's driver — their location message is rejected."""
    job = await make_job(
        session_maker, customer_user, status=JobStatus.en_route_pickup, driver=driver_user
    )
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "location", "job_id": str(job.id), "lat": 1.0, "lng": 2.0})
        reply = ws.receive_json()
        assert reply["type"] == "error"


async def test_location_rejected_when_job_not_active(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.completed, driver=driver_user
    )
    with TestClient(app).websocket_connect("/v1/ws?token=driver-token") as ws:
        ws.send_json({"type": "location", "job_id": str(job.id), "lat": 1.0, "lng": 2.0})
        reply = ws.receive_json()
        assert reply["type"] == "error"


# ---- public share-track viewers (TRK-6 WS half) --------------------------------------


async def test_share_track_ws_receives_reduced_job_event(
    app: FastAPI,
    client: AsyncClient,
    tokens: Any,
    customer_user: User,
    session_maker: async_sessionmaker[AsyncSession],
    fake_redis: FakeRedis,
    seeded_config: Any,
) -> None:
    driver = await make_available_driver(session_maker, fake_redis, firebase_uid="track-driver")
    tokens["track-driver-token"] = {"uid": driver.firebase_uid}

    quote = await _get_quote(app, client)
    create_resp = await client.post(
        "/v1/jobs", headers=AUTH_CUSTOMER, json=_job_body(quote["quote_id"])
    )
    share_token = create_resp.json()["share_token"]
    job_id = create_resp.json()["id"]

    with TestClient(app).websocket_connect(f"/v1/ws/track/{share_token}") as ws:
        accept_resp = await client.post(
            f"/v1/jobs/{job_id}/accept", headers={"Authorization": "Bearer track-driver-token"}
        )
        assert accept_resp.status_code == 200

        event = ws.receive_json()
        assert event["type"] == "job_event"
        assert event["status"] == "assigned"
        assert event["driver"]["first_name"] == "Test"
        # No PII beyond first name + plate: nothing price/id-shaped leaks over the
        # public track channel.
        assert set(event.keys()) == {"type", "job_id", "status", "driver"}
        assert "quoted_price" not in event
        assert "driver_id" not in event
        assert "final_price" not in event


async def test_share_track_ws_receives_driver_location(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.in_transit, driver=driver_user
    )
    tc = TestClient(app)
    with (
        tc.websocket_connect(f"/v1/ws/track/{job.share_token}") as viewer_ws,
        tc.websocket_connect("/v1/ws?token=driver-token") as driver_ws,
    ):
        driver_ws.send_json({"type": "location", "job_id": str(job.id), "lat": 6.3, "lng": -75.6})
        event = viewer_ws.receive_json()
        assert event == {
            "type": "driver_location",
            "job_id": str(job.id),
            "lat": 6.3,
            "lng": -75.6,
        }


async def test_share_track_ws_unknown_token_closes_4004(app: FastAPI) -> None:
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect(f"/v1/ws/track/{uuid.uuid4()}") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4004


async def test_share_track_ws_malformed_token_closes_4004(app: FastAPI) -> None:
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect("/v1/ws/track/not-a-uuid") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4004


async def test_share_track_ws_closes_4004_24h_after_completion(
    app: FastAPI,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
) -> None:
    """Same 24h expiry as GET /v1/track/{token} -- a stale share link should
    behave identically to an unknown one for this read-only viewer channel."""
    job = await make_job(session_maker, customer_user, status=JobStatus.completed)
    async with session_maker() as session:
        db_job = await session.get(Job, job.id)
        assert db_job is not None
        db_job.completed_at = datetime.now(UTC) - timedelta(hours=25)
        await session.commit()

    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect(f"/v1/ws/track/{job.share_token}") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4004


# ---- connection registry cleanup -------------------------------------------------


async def test_disconnect_cleans_up_manager_state(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    connection_manager: ConnectionManager,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "subscribe", "job_id": str(job.id)})
        ws.receive_json()
        assert connection_manager.local_sockets(customer_user.id) != set()
        assert customer_user.id in connection_manager.local_job_subscribers(job.id)

    # socket closed on `with` exit — registry should be fully cleaned up.
    assert connection_manager.local_sockets(customer_user.id) == set()
    assert connection_manager.local_job_subscribers(job.id) == set()


async def test_second_device_keeps_subscription_alive_until_last_disconnect(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    connection_manager: ConnectionManager,
) -> None:
    job = await make_job(session_maker, customer_user, status=JobStatus.matching)
    tc = TestClient(app)
    with tc.websocket_connect("/v1/ws?token=customer-token") as ws1:
        ws1.send_json({"type": "subscribe", "job_id": str(job.id)})
        ws1.receive_json()

        with tc.websocket_connect("/v1/ws?token=customer-token") as _ws2:
            assert len(connection_manager.local_sockets(customer_user.id)) == 2
            # _ws2 disconnects here (end of inner `with`), ws1 stays open.

        assert len(connection_manager.local_sockets(customer_user.id)) == 1
        assert customer_user.id in connection_manager.local_job_subscribers(job.id)

    assert connection_manager.local_sockets(customer_user.id) == set()
    assert connection_manager.local_job_subscribers(job.id) == set()
