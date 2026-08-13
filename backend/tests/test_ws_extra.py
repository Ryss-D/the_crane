"""Additional app/api/ws.py coverage: WS-token edge cases, malformed client messages,
and the heartbeat loop's own timing logic. Kept as a separate file from test_ws.py
(rather than appended there) purely to avoid churn in that large, heavily-trafficked
file; it shares the exact same fixtures (tests/conftest.py) and patterns (TestClient
for the WS side, per test_ws.py's own module docstring on why that's needed).
"""

import asyncio
import contextlib
from typing import Any

import pytest
from fastapi import FastAPI
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.api import ws as ws_module
from app.models.job import JobStatus
from app.models.user import User
from app.services.connection_manager import ConnectionManager
from tests.conftest import make_job


@pytest.fixture
def tokens(
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
    driver_user: User,
) -> dict[str, dict[str, Any]]:
    """Mirrors test_ws.py's own `tokens` fixture -- fixtures defined in a test module
    aren't shared across files, and duplicating this small one here is simpler than
    promoting it to conftest.py just for this file."""
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    verified_tokens["driver-token"] = {"uid": driver_user.firebase_uid}
    return verified_tokens


# ---- WS token edge cases (verify_ws_token) -----------------------------------------


async def test_connect_with_claims_missing_uid_closes_4001(
    app: FastAPI, tokens: dict[str, dict[str, Any]]
) -> None:
    """The verifier itself succeeds (no exception) but the claims it returns carry
    neither `uid` nor `sub` -- verify_ws_token treats that the same as a bad token."""
    tokens["no-uid-token"] = {"some": "claim"}
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect("/v1/ws?token=no-uid-token") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4001


async def test_connect_with_unknown_user_closes_4001(
    app: FastAPI, tokens: dict[str, dict[str, Any]]
) -> None:
    """Claims verify fine and carry a uid, but no users row matches it (never
    synced) -- verify_ws_token's final `session.scalar(...)` returns None."""
    tokens["never-synced-token"] = {"uid": "never-synced-uid"}
    with (
        pytest.raises(WebSocketDisconnect) as exc_info,
        TestClient(app).websocket_connect("/v1/ws?token=never-synced-token") as ws,
    ):
        ws.receive_text()
    assert exc_info.value.code == 4001


# ---- malformed / edge-case client messages -----------------------------------------


async def test_valid_json_non_object_returns_error(app: FastAPI, tokens: Any) -> None:
    """`json.loads` succeeds but yields something other than a dict (e.g. a bare
    JSON array) -- a distinct rejection path from malformed JSON syntax (which
    test_ws.py's test_malformed_json_returns_error already covers)."""
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_text("[1, 2, 3]")
        reply = ws.receive_json()
        assert reply == {"type": "error", "detail": "Expected a JSON object"}


async def test_pong_is_silently_accepted(app: FastAPI, tokens: Any) -> None:
    """A `pong` heartbeat ack produces no reply of its own -- it only touches the
    activity marker. Confirmed by checking the very next message is the *next*
    request's ack, not some stray error queued in between."""
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "pong"})
        ws.send_json({"type": "not_a_real_type"})
        reply = ws.receive_json()
        assert reply["type"] == "error"  # from the second message, not the pong


@pytest.mark.parametrize(
    "message",
    [
        {"type": "subscribe"},  # job_id missing entirely
        {"type": "subscribe", "job_id": "not-a-valid-uuid"},  # not a UUID
        {"type": "subscribe", "job_id": 12345},  # not a string at all
    ],
)
async def test_subscribe_with_bad_job_id_returns_error(
    app: FastAPI, tokens: Any, message: dict[str, Any]
) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json(message)
        reply = ws.receive_json()
        assert reply == {"type": "error", "detail": "job_id is required"}


async def test_unsubscribe_with_bad_job_id_returns_error(app: FastAPI, tokens: Any) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=customer-token") as ws:
        ws.send_json({"type": "unsubscribe", "job_id": "not-a-valid-uuid"})
        reply = ws.receive_json()
        assert reply == {"type": "error", "detail": "job_id is required"}


async def test_location_with_bad_job_id_returns_error(app: FastAPI, tokens: Any) -> None:
    with TestClient(app).websocket_connect("/v1/ws?token=driver-token") as ws:
        ws.send_json({"type": "location", "job_id": "not-a-valid-uuid", "lat": 1.0, "lng": 2.0})
        reply = ws.receive_json()
        assert reply == {"type": "error", "detail": "job_id/lat/lng are required"}


async def test_location_with_non_numeric_lat_lng_returns_error(
    app: FastAPI,
    tokens: Any,
    session_maker: async_sessionmaker[AsyncSession],
    customer_user: User,
    driver_user: User,
) -> None:
    job = await make_job(
        session_maker, customer_user, status=JobStatus.en_route_pickup, driver=driver_user
    )
    with TestClient(app).websocket_connect("/v1/ws?token=driver-token") as ws:
        ws.send_json(
            {"type": "location", "job_id": str(job.id), "lat": "not-a-number", "lng": 2.0}
        )
        reply = ws.receive_json()
        assert reply == {"type": "error", "detail": "job_id/lat/lng are required"}


# ---- heartbeat loop (TRK-1) ---------------------------------------------------------


class _FakeHeartbeatSocket:
    """Duck-types just enough of WebSocket for `_heartbeat_loop`/`ConnectionManager.
    send_json` -- no real connection needed to exercise the loop's own timing logic."""

    def __init__(self) -> None:
        self.sent: list[dict[str, Any]] = []
        self.closed_with: int | None = None

    async def send_json(self, payload: dict[str, Any]) -> None:
        self.sent.append(payload)

    async def close(self, code: int | None = None) -> None:
        self.closed_with = code


async def test_heartbeat_loop_pings_while_activity_is_recent(
    monkeypatch: pytest.MonkeyPatch, connection_manager: ConnectionManager
) -> None:
    monkeypatch.setattr(ws_module, "HEARTBEAT_INTERVAL_SECONDS", 0.01)
    monkeypatch.setattr(ws_module, "HEARTBEAT_TIMEOUT_SECONDS", 10)  # far from stale
    fake_ws = _FakeHeartbeatSocket()
    activity = ws_module._Activity()

    task = asyncio.create_task(ws_module._heartbeat_loop(fake_ws, connection_manager, activity))
    await asyncio.sleep(0.03)
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task

    assert {"type": "ping"} in fake_ws.sent
    assert fake_ws.closed_with is None


async def test_heartbeat_loop_closes_socket_once_activity_goes_stale(
    monkeypatch: pytest.MonkeyPatch, connection_manager: ConnectionManager
) -> None:
    monkeypatch.setattr(ws_module, "HEARTBEAT_INTERVAL_SECONDS", 0.01)
    monkeypatch.setattr(ws_module, "HEARTBEAT_TIMEOUT_SECONDS", 0.01)
    fake_ws = _FakeHeartbeatSocket()
    activity = ws_module._Activity()
    activity.last -= 10  # already far past the (tiny) timeout

    await ws_module._heartbeat_loop(fake_ws, connection_manager, activity)  # returns on its own

    assert fake_ws.closed_with == 1001
