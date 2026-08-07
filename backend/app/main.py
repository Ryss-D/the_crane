import asyncio
import contextlib
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import admin, auth, drivers, fleets, jobs, ratings, users, vehicles, ws
from app.core.config import get_settings
from app.core.database import dispose_engine, get_session, get_sessionmaker
from app.core.redis import close_redis, get_redis, get_redis_client
from app.models.job import Job, JobOffer, JobStatus
from app.services.config import RedisLike
from app.services.connection_manager import ConnectionManager, get_connection_manager
from app.services.dispatch import OfferNotifier, get_offer_notifier
from app.services.jobs import JobEventHook, get_job_event_hook
from app.services.realtime import broadcast_job_event, notify_driver_offer
from app.workers.offer_expiry import run_offer_expiry_worker


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    worker_task: asyncio.Task[None] | None = None
    if get_settings().enable_workers:
        # DSP-4: offer-expiry sweep. Guarded so test app instances (enable_workers is
        # False there) never spin up a background loop against a real DB/Redis; ASGI
        # test transports don't run lifespan at all in this suite, but the guard also
        # protects any future test setup that does.
        worker_task = asyncio.create_task(
            run_offer_expiry_worker(get_sessionmaker(), get_redis_client())
        )
    yield
    if worker_task is not None:
        worker_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await worker_task
    await dispose_engine()
    await close_redis()


def _real_job_event_hook(
    session: Annotated[AsyncSession, Depends(get_session)],
    redis: Annotated[RedisLike, Depends(get_redis)],
    manager: Annotated[ConnectionManager, Depends(get_connection_manager)],
) -> JobEventHook:
    """TRK-3: production override for `get_job_event_hook` — broadcasts every
    transition over WS via the connection manager (services/realtime.py). Declared as
    its own Depends-based dependency (rather than called directly) so its session/
    redis/manager come from the very same override chain everything else uses,
    including in tests that swap get_session/get_redis/get_connection_manager."""

    async def hook(job: Job, old_status: JobStatus, new_status: JobStatus) -> None:
        await broadcast_job_event(session, redis, manager, job, old_status, new_status)

    return hook


def _real_offer_notifier(
    session: Annotated[AsyncSession, Depends(get_session)],
    redis: Annotated[RedisLike, Depends(get_redis)],
    manager: Annotated[ConnectionManager, Depends(get_connection_manager)],
) -> OfferNotifier:
    """TRK-3: production override for `get_offer_notifier` — pushes a `job_offer` WS
    message directly to the offered driver's live connections, plus an FCM push to
    their `fcm_token` (session comes from this same override chain, like
    `_real_job_event_hook` above)."""

    async def notifier(offer: JobOffer, job: Job) -> None:
        await notify_driver_offer(session, redis, manager, offer, job)

    return notifier


def create_app() -> FastAPI:
    app = FastAPI(title="The Crane API", version="0.1.0", lifespan=lifespan)

    # WEB-1: web-client/admin call this API directly from the browser.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=get_settings().cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(auth.router, prefix="/v1")
    app.include_router(users.router, prefix="/v1")
    app.include_router(admin.router, prefix="/v1")
    app.include_router(jobs.router, prefix="/v1")
    app.include_router(jobs.track_router, prefix="/v1")  # public share-token tracking
    app.include_router(ratings.router, prefix="/v1")  # RAT-1: /v1/jobs/{id}/rating(s)
    app.include_router(drivers.router, prefix="/v1")
    app.include_router(fleets.router, prefix="/v1")
    app.include_router(vehicles.router, prefix="/v1")
    app.include_router(ws.router, prefix="/v1")

    # TRK-3: wire the real broadcasters as the actual overrides — the no-op defaults
    # in jobs.py/dispatch.py only apply where a test explicitly swaps these back.
    app.dependency_overrides[get_job_event_hook] = _real_job_event_hook
    app.dependency_overrides[get_offer_notifier] = _real_offer_notifier
    return app


app = create_app()
