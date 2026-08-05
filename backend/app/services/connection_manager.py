"""In-process WS connection registry + Redis pub/sub fan-out (TRK-1).

Two lookups are kept in sync as connections come and go:

  - ``_user_sockets``: ``user_id -> set[WebSocket]`` — a user may have several live
    sockets (multiple tabs/devices); every one of them gets everything addressed to
    that user.
  - ``_job_subscribers`` / ``_job_track_subscribers``: ``job_id -> set[id]`` — who
    (authenticated users, or anonymous share-token viewers respectively) wants this
    job's events. Kept as two separate maps rather than one because they map to two
    different Redis channels carrying different payload shapes (see below).

Nothing is ever delivered "directly" between local sockets, even though tests and dev
run a single process — every event is published to Redis first
(``publish_job``/``publish_job_track``/``publish_to_user``), and delivery to local
sockets happens only via a background relay task that subscribed to that same Redis
channel. That's what makes this correct across multiple API workers (PLAN §2, TRK-1's
AC: "two clients on different workers receive each other's job events"): every worker
runs this same class, every worker publishes to Redis, and every worker relays to
whichever of its own local sockets care. One relay task per channel is kept alive for
as long as at least one local subscriber wants it (refcounted), and cancelled once the
last one leaves — cheap in the common case where a job has a handful of watchers.

Three channel families:

  - ``job:{job_id}:events`` — full job_event/driver_location payloads for the job's
    authenticated customer + assigned driver (app/services/realtime.py builds these).
  - ``job:{job_id}:track`` — the reduced, PII-safe variant of the same events for
    public share-token viewers (TRK-6 WS half) — never carries price/ids, only what
    GET /v1/track/{token} already exposes.
  - ``user:{user_id}:events`` — direct-to-user pushes that aren't tied to a job
    subscription, namely incoming dispatch offers (TRK-3's offer_notifier). Every
    connected socket auto-subscribes its owner's user channel on connect so an offer
    reaches a driver regardless of which worker holds their idle socket.
"""

import asyncio
import contextlib
import json
import logging
import uuid
from collections.abc import Callable
from functools import lru_cache
from typing import Protocol

from fastapi import WebSocket

from app.services.config import RedisLike

ChannelFn = Callable[[uuid.UUID], str]

logger = logging.getLogger(__name__)


class PubSubLike(Protocol):
    """The slice of redis.asyncio's PubSub object this module drives."""

    async def subscribe(self, *channels: str) -> object: ...
    async def unsubscribe(self, *channels: str) -> object: ...
    async def get_message(
        self, *, ignore_subscribe_messages: bool = True, timeout: float | None = None
    ) -> dict[str, object] | None: ...
    async def close(self) -> None: ...


class PubSubRedisLike(RedisLike, Protocol):
    """RedisLike plus the pub/sub surface — matches redis.asyncio.Redis directly, so
    production code is unchanged versus the FakeRedis emulation tests use."""

    async def publish(self, channel: str, message: str) -> object: ...
    def pubsub(self) -> PubSubLike: ...


def _job_channel(job_id: uuid.UUID) -> str:
    return f"job:{job_id}:events"


def _job_track_channel(job_id: uuid.UUID) -> str:
    return f"job:{job_id}:track"


def _user_channel(user_id: uuid.UUID) -> str:
    return f"user:{user_id}:events"


class ConnectionManager:
    def __init__(self) -> None:
        self._user_sockets: dict[uuid.UUID, set[WebSocket]] = {}
        self._job_subscribers: dict[uuid.UUID, set[uuid.UUID]] = {}
        self._job_track_subscribers: dict[uuid.UUID, set[uuid.UUID]] = {}
        self._send_locks: dict[WebSocket, asyncio.Lock] = {}
        self._relay_tasks: dict[str, asyncio.Task[None]] = {}
        self._relay_refcount: dict[str, int] = {}
        self._relay_lock = asyncio.Lock()

    # ---- connection lifecycle ------------------------------------------------

    async def connect(
        self, redis: PubSubRedisLike, user_id: uuid.UUID, websocket: WebSocket
    ) -> None:
        """Register a live socket and start relaying that user's direct channel."""
        self._user_sockets.setdefault(user_id, set()).add(websocket)
        await self._ensure_relay(redis, _user_channel(user_id))

    async def disconnect(
        self, redis: PubSubRedisLike, user_id: uuid.UUID, websocket: WebSocket
    ) -> None:
        """Drop the socket; tear down job/track subscriptions once its owner has none left."""
        sockets = self._user_sockets.get(user_id)
        if sockets is not None and websocket in sockets:
            sockets.discard(websocket)
            if not sockets:
                del self._user_sockets[user_id]
            await self._release_relay(_user_channel(user_id))
        self._send_locks.pop(websocket, None)

        if user_id in self._user_sockets:
            return  # another tab/device is still connected — keep subscriptions alive

        for job_id in [j for j, subs in self._job_subscribers.items() if user_id in subs]:
            await self._unsubscribe(self._job_subscribers, _job_channel, redis, job_id, user_id)
        for job_id in [j for j, subs in self._job_track_subscribers.items() if user_id in subs]:
            await self._unsubscribe(
                self._job_track_subscribers, _job_track_channel, redis, job_id, user_id
            )

    # ---- job subscriptions -----------------------------------------------------

    async def subscribe_job(
        self, redis: PubSubRedisLike, user_id: uuid.UUID, job_id: uuid.UUID
    ) -> None:
        """Full job channel — customer/assigned-driver access already checked by the caller."""
        await self._subscribe(self._job_subscribers, _job_channel, redis, job_id, user_id)

    async def unsubscribe_job(
        self, redis: PubSubRedisLike, user_id: uuid.UUID, job_id: uuid.UUID
    ) -> None:
        await self._unsubscribe(self._job_subscribers, _job_channel, redis, job_id, user_id)

    async def subscribe_job_track(
        self, redis: PubSubRedisLike, viewer_id: uuid.UUID, job_id: uuid.UUID
    ) -> None:
        """Reduced/PII-safe channel for a public share-token viewer (TRK-6)."""
        await self._subscribe(
            self._job_track_subscribers, _job_track_channel, redis, job_id, viewer_id
        )

    async def unsubscribe_job_track(
        self, redis: PubSubRedisLike, viewer_id: uuid.UUID, job_id: uuid.UUID
    ) -> None:
        await self._unsubscribe(
            self._job_track_subscribers, _job_track_channel, redis, job_id, viewer_id
        )

    # ---- publishing (always through Redis — see module docstring) -------------

    async def publish_job(self, redis: PubSubRedisLike, job_id: uuid.UUID, message: dict) -> None:
        await redis.publish(_job_channel(job_id), json.dumps(message))

    async def publish_job_track(
        self, redis: PubSubRedisLike, job_id: uuid.UUID, message: dict
    ) -> None:
        await redis.publish(_job_track_channel(job_id), json.dumps(message))

    async def publish_to_user(
        self, redis: PubSubRedisLike, user_id: uuid.UUID, message: dict
    ) -> None:
        await redis.publish(_user_channel(user_id), json.dumps(message))

    # ---- serialized per-socket sends -------------------------------------------

    async def send_json(self, websocket: WebSocket, payload: dict) -> None:
        """All sends (relay fan-out, heartbeat pings, ack/error frames) go through
        here so a relay callback and the connection's own heartbeat loop never write
        to the same socket concurrently (ASGI sends aren't safe to interleave)."""
        lock = self._send_locks.setdefault(websocket, asyncio.Lock())
        async with lock:
            with contextlib.suppress(Exception):
                await websocket.send_json(payload)

    # ---- introspection for tests -----------------------------------------------

    def local_job_subscribers(self, job_id: uuid.UUID) -> set[uuid.UUID]:
        return set(self._job_subscribers.get(job_id, set()))

    def local_job_track_subscribers(self, job_id: uuid.UUID) -> set[uuid.UUID]:
        return set(self._job_track_subscribers.get(job_id, set()))

    def local_sockets(self, user_id: uuid.UUID) -> set[WebSocket]:
        return set(self._user_sockets.get(user_id, set()))

    # ---- private: generic subscribe/unsubscribe + relay refcounting -----------

    async def _subscribe(
        self,
        subscriber_map: dict[uuid.UUID, set[uuid.UUID]],
        channel_fn: ChannelFn,
        redis: PubSubRedisLike,
        entity_id: uuid.UUID,
        member_id: uuid.UUID,
    ) -> None:
        subs = subscriber_map.setdefault(entity_id, set())
        if member_id not in subs:
            subs.add(member_id)
            await self._ensure_relay(redis, channel_fn(entity_id))

    async def _unsubscribe(
        self,
        subscriber_map: dict[uuid.UUID, set[uuid.UUID]],
        channel_fn: ChannelFn,
        redis: PubSubRedisLike,
        entity_id: uuid.UUID,
        member_id: uuid.UUID,
    ) -> None:
        subs = subscriber_map.get(entity_id)
        if subs is None or member_id not in subs:
            return
        subs.discard(member_id)
        if not subs:
            del subscriber_map[entity_id]
        await self._release_relay(channel_fn(entity_id))

    async def _ensure_relay(self, redis: PubSubRedisLike, channel: str) -> None:
        async with self._relay_lock:
            self._relay_refcount[channel] = self._relay_refcount.get(channel, 0) + 1
            if channel not in self._relay_tasks:
                pubsub = redis.pubsub()
                await pubsub.subscribe(channel)
                self._relay_tasks[channel] = asyncio.create_task(self._relay_loop(channel, pubsub))

    async def _release_relay(self, channel: str) -> None:
        async with self._relay_lock:
            if channel not in self._relay_refcount:
                return
            self._relay_refcount[channel] -= 1
            if self._relay_refcount[channel] > 0:
                return
            del self._relay_refcount[channel]
            task = self._relay_tasks.pop(channel, None)
        if task is not None:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

    async def _relay_loop(self, channel: str, pubsub: PubSubLike) -> None:
        """Poll this channel's pubsub until cancelled, fanning each message out to
        whichever local sockets currently care about it (looked up fresh every time,
        never cached, since subscribers churn as connections come and go)."""
        try:
            while True:
                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if message is None:
                    continue
                await self._dispatch(channel, message["data"])
        except asyncio.CancelledError:
            raise
        finally:
            with contextlib.suppress(Exception):
                await pubsub.close()

    async def _dispatch(self, channel: str, raw: object) -> None:
        try:
            payload = json.loads(raw)
        except (TypeError, ValueError):
            logger.warning("dropping malformed pub/sub payload on %s", channel)
            return

        kind, id_str, topic = channel.split(":")
        entity_id = uuid.UUID(id_str)
        if kind == "job":
            subscriber_map = (
                self._job_subscribers if topic == "events" else self._job_track_subscribers
            )
            target_user_ids = subscriber_map.get(entity_id, set())
        else:  # kind == "user"
            target_user_ids = {entity_id}

        for user_id in target_user_ids:
            for websocket in self._user_sockets.get(user_id, set()):
                await self.send_json(websocket, payload)


@lru_cache
def _default_manager() -> ConnectionManager:
    return ConnectionManager()


def get_connection_manager() -> ConnectionManager:
    """FastAPI dependency returning the process-wide connection manager; override in
    tests (same pattern as get_redis/get_token_verifier) for per-test isolation."""
    return _default_manager()
