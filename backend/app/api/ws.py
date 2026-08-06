"""WebSocket router (TRK-1/2/3/6): authed realtime channel + the public share-track
viewer channel. Pre-registered in main.py under the /v1 prefix.

Auth: `WS /v1/ws?token=<firebase_id_token>`. Firebase ID tokens aren't guaranteed to
travel as an `Authorization` header on every WS client (browsers' native WebSocket API
can't set custom handshake headers at all), so the token rides as a query param
instead — the simplest option, matches PLAN's "Bearer-style auth intent" without
needing a post-connect handshake message, and every client already has the token in
hand from the same place it puts it in the `Authorization` header for REST calls.
`verify_ws_token` reuses `get_token_verifier()`/`claims_uid()` from core/security.py
(the same pieces `get_current_user` builds on) so Firebase verification logic lives in
exactly one place; bad/missing token closes the socket with code 4001.

Message protocol
-----------------
Client -> server:
  {"type": "subscribe", "job_id": "<uuid>"}    — join a job's event stream (must be
                                                   its customer or assigned driver)
  {"type": "unsubscribe", "job_id": "<uuid>"}  — leave it
  {"type": "location", "job_id": "<uuid>", "lat": .., "lng": ..}
                                                — driver only, must be the job's
                                                   assigned driver, job must be in an
                                                   active status (assigned..in_transit)
  {"type": "pong"}                             — heartbeat ack (any message counts
                                                   as activity, this is just the
                                                   explicit one)

Server -> client:
  {"type": "ping"}                                          — heartbeat, every ~20s
  {"type": "subscribed"/"unsubscribed", "job_id": ..}        — subscribe/unsubscribe ack
  {"type": "error", "detail": "..."}                         — rejected message
  {"type": "job_event", "job_id": .., "status": .., ...}     — TRK-3, via services/realtime.py
  {"type": "driver_location", "job_id": .., "lat": .., "lng": ..} — TRK-2
  {"type": "job_offer", "job_id": .., "offer_id": .., ...}   — TRK-3, direct to the
                                                                 offered driver

`WS /v1/ws/track/{share_token}` is the public, read-only counterpart (TRK-6): no auth,
auto-subscribed to exactly one job, can only ever receive `job_event`/`driver_location`
(the reduced/PII-safe variant — see services/realtime.py's `JobTrackEvent`) and never
`job_offer`. Kept as a separate path rather than an alternate `/v1/ws?share_token=`
query param on the authed endpoint: the two have basically nothing in common (no user
row, no send-side permission checks, exactly one implicit subscription) and folding
them into one handler would mean threading an `is_read_only` flag through every branch
of the authed one for no real benefit.
"""

import asyncio
import contextlib
import json
import time
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.redis import get_redis
from app.core.security import TokenVerifier, claims_uid, get_token_verifier
from app.models.job import DriverLocationSnapshot, Job, JobStatus
from app.models.user import User
from app.services.config import RedisLike
from app.services.connection_manager import ConnectionManager, get_connection_manager
from app.services.realtime import publish_driver_location

router = APIRouter(prefix="/ws", tags=["ws"])

HEARTBEAT_INTERVAL_SECONDS = 20
HEARTBEAT_TIMEOUT_SECONDS = 45  # ~2 missed pings before we give up on a socket

# Statuses in which a driver's WS location message is accepted (mirrors the job being
# actively "in progress" — before `assigned` there's no driver to track yet, after
# `delivered` the trip is over).
ACTIVE_DRIVER_STATUSES = frozenset(
    {
        JobStatus.assigned,
        JobStatus.en_route_pickup,
        JobStatus.arrived_pickup,
        JobStatus.loading,
        JobStatus.in_transit,
    }
)

# TRK-2: TTL on the "live" position key — short enough that a dead/backgrounded
# driver's last position stops being served as current within a few missed beats.
LOCATION_TTL_SECONDS = 30

SessionDep = Annotated[AsyncSession, Depends(get_session)]
RedisDep = Annotated[RedisLike, Depends(get_redis)]
VerifierDep = Annotated[TokenVerifier, Depends(get_token_verifier)]
ManagerDep = Annotated[ConnectionManager, Depends(get_connection_manager)]


class _Activity:
    """Mutable last-seen-activity marker, shared between the receive loop and the
    heartbeat task for one connection."""

    def __init__(self) -> None:
        self.last = time.monotonic()

    def touch(self) -> None:
        self.last = time.monotonic()


async def verify_ws_token(
    token: str, verifier: TokenVerifier, session: AsyncSession
) -> User | None:
    """Resolve a WS `?token=` query param to a users row, reusing the same
    TokenVerifier/claims_uid pieces `get_current_user` is built from (core/security.py)
    rather than re-touching Firebase. Returns None on any failure — bad token, unknown
    claims shape, or no matching users row — callers close with 4001 either way."""
    try:
        claims = verifier(token)
    except Exception:
        return None
    if not (claims.get("uid") or claims.get("sub")):
        return None
    return await session.scalar(select(User).where(User.firebase_uid == claims_uid(claims)))


def _as_aware(dt: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC (all stamps are UTC)."""
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


def _parse_uuid(value: Any) -> uuid.UUID | None:
    if not isinstance(value, str):
        return None
    try:
        return uuid.UUID(value)
    except ValueError:
        return None


async def _heartbeat_loop(
    websocket: WebSocket, manager: ConnectionManager, activity: _Activity
) -> None:
    """TRK-1: server-initiated ping every ~20s; force-close a socket that's gone
    quiet for HEARTBEAT_TIMEOUT_SECONDS (dead peer, e.g. network drop with no FIN)."""
    while True:
        await asyncio.sleep(HEARTBEAT_INTERVAL_SECONDS)
        if time.monotonic() - activity.last > HEARTBEAT_TIMEOUT_SECONDS:
            with contextlib.suppress(Exception):
                await websocket.close(code=1001)
            return
        await manager.send_json(websocket, {"type": "ping"})


async def _handle_subscribe(
    data: dict[str, Any],
    websocket: WebSocket,
    session: AsyncSession,
    redis: RedisLike,
    manager: ConnectionManager,
    user: User,
) -> None:
    job_id = _parse_uuid(data.get("job_id"))
    if job_id is None:
        await manager.send_json(websocket, {"type": "error", "detail": "job_id is required"})
        return
    job = await session.get(Job, job_id)
    if job is None or user.id not in (job.customer_id, job.driver_id):
        await manager.send_json(
            websocket, {"type": "error", "detail": "Not authorized for this job"}
        )
        return
    await manager.subscribe_job(redis, user.id, job.id)
    await manager.send_json(websocket, {"type": "subscribed", "job_id": str(job.id)})


async def _handle_unsubscribe(
    data: dict[str, Any],
    websocket: WebSocket,
    redis: RedisLike,
    manager: ConnectionManager,
    user: User,
) -> None:
    job_id = _parse_uuid(data.get("job_id"))
    if job_id is None:
        await manager.send_json(websocket, {"type": "error", "detail": "job_id is required"})
        return
    await manager.unsubscribe_job(redis, user.id, job_id)
    await manager.send_json(websocket, {"type": "unsubscribed", "job_id": str(job_id)})


async def _handle_location(
    data: dict[str, Any],
    websocket: WebSocket,
    session: AsyncSession,
    redis: RedisLike,
    manager: ConnectionManager,
    user: User,
) -> None:
    job_id = _parse_uuid(data.get("job_id"))
    lat, lng = data.get("lat"), data.get("lng")
    if job_id is None or not isinstance(lat, int | float) or not isinstance(lng, int | float):
        await manager.send_json(
            websocket, {"type": "error", "detail": "job_id/lat/lng are required"}
        )
        return
    job = await session.get(Job, job_id)
    if job is None or job.driver_id != user.id:
        await manager.send_json(
            websocket, {"type": "error", "detail": "Not the assigned driver for this job"}
        )
        return
    if job.status not in ACTIVE_DRIVER_STATUSES:
        await manager.send_json(
            websocket, {"type": "error", "detail": f"Job is not active (status={job.status.value})"}
        )
        return

    lat, lng = float(lat), float(lng)
    await redis.set(
        f"job:{job.id}:location",
        json.dumps({"lat": lat, "lng": lng}),
        ex=LOCATION_TTL_SECONDS,
    )
    # TRK-2: one snapshot row per location message (~5s cadence from the client).
    # Cheap enough for MVP scale; if volume ever matters, sample every Nth message
    # (or time-bucket, e.g. at most one row per N seconds per job) instead of
    # snapshotting every single one — the "audit trail" use case doesn't need
    # sub-5s granularity in Postgres, only the live Redis key does.
    session.add(
        DriverLocationSnapshot(
            job_id=job.id, driver_id=user.id, lat=lat, lng=lng, job_status=job.status
        )
    )
    await session.commit()

    await publish_driver_location(redis, manager, job.id, lat, lng)


async def _dispatch_message(
    raw: str,
    websocket: WebSocket,
    session: AsyncSession,
    redis: RedisLike,
    manager: ConnectionManager,
    user: User,
    activity: _Activity,
) -> None:
    activity.touch()
    try:
        data = json.loads(raw)
    except (TypeError, ValueError):
        await manager.send_json(websocket, {"type": "error", "detail": "Malformed JSON"})
        return
    if not isinstance(data, dict):
        await manager.send_json(websocket, {"type": "error", "detail": "Expected a JSON object"})
        return

    msg_type = data.get("type")
    if msg_type == "pong":
        return  # activity already touched above — that's the whole point of pong
    if msg_type == "subscribe":
        await _handle_subscribe(data, websocket, session, redis, manager, user)
    elif msg_type == "unsubscribe":
        await _handle_unsubscribe(data, websocket, redis, manager, user)
    elif msg_type == "location":
        await _handle_location(data, websocket, session, redis, manager, user)
    else:
        await manager.send_json(
            websocket, {"type": "error", "detail": f"Unknown message type {msg_type!r}"}
        )


@router.websocket("")
async def ws_endpoint(
    websocket: WebSocket,
    session: SessionDep,
    redis: RedisDep,
    verifier: VerifierDep,
    manager: ManagerDep,
    token: str | None = None,
) -> None:
    """TRK-1: `WS /v1/ws?token=<firebase_id_token>` — the authed realtime channel."""
    if not token:
        await websocket.accept()
        await websocket.close(code=4001)
        return
    user = await verify_ws_token(token, verifier, session)
    if user is None:
        await websocket.accept()
        await websocket.close(code=4001)
        return

    await websocket.accept()
    await manager.connect(redis, user.id, websocket)
    activity = _Activity()
    heartbeat_task = asyncio.create_task(_heartbeat_loop(websocket, manager, activity))
    try:
        while True:
            raw = await websocket.receive_text()
            await _dispatch_message(raw, websocket, session, redis, manager, user, activity)
    except WebSocketDisconnect:
        pass
    finally:
        heartbeat_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await heartbeat_task
        await manager.disconnect(redis, user.id, websocket)


@router.websocket("/track/{share_token}")
async def ws_track_endpoint(
    websocket: WebSocket,
    share_token: str,
    session: SessionDep,
    redis: RedisDep,
    manager: ManagerDep,
) -> None:
    """TRK-6 (WS half): public, read-only, auto-subscribed to exactly one job.

    No auth — same trust model as GET /v1/track/{token} (anyone with the link).
    Never receives more than that endpoint does: only the reduced job_event/
    driver_location variants (services/realtime.py publishes those on a separate
    `job:{id}:track` channel from the authenticated `job:{id}:events` one). Client
    frames are read and discarded (a viewer has nothing to say) — this only exists so
    `receive_text()` can observe the disconnect and clean the registry up.
    """
    try:
        token_uuid = uuid.UUID(share_token)
    except ValueError:
        await websocket.accept()
        await websocket.close(code=4004)
        return
    job = await session.scalar(select(Job).where(Job.share_token == token_uuid))
    ended_at = job.completed_at or job.cancelled_at if job is not None else None
    expired = ended_at is not None and datetime.now(UTC) - _as_aware(ended_at) > timedelta(hours=24)
    if job is None or expired:
        await websocket.accept()
        await websocket.close(code=4004)
        return

    await websocket.accept()
    viewer_id = token_uuid  # share tokens are unique per job — safe to reuse as the
    # connection manager's "identity" key for this read-only, non-user connection.
    await manager.connect(redis, viewer_id, websocket)
    await manager.subscribe_job_track(redis, viewer_id, job.id)
    activity = _Activity()
    heartbeat_task = asyncio.create_task(_heartbeat_loop(websocket, manager, activity))
    try:
        while True:
            await websocket.receive_text()
            activity.touch()
    except WebSocketDisconnect:
        pass
    finally:
        heartbeat_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await heartbeat_task
        await manager.unsubscribe_job_track(redis, viewer_id, job.id)
        await manager.disconnect(redis, viewer_id, websocket)
