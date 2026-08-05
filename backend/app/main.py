import asyncio
import contextlib
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import admin, auth, drivers, jobs, users, ws
from app.core.config import get_settings
from app.core.database import dispose_engine, get_sessionmaker
from app.core.redis import close_redis, get_redis_client
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


def create_app() -> FastAPI:
    app = FastAPI(title="The Crane API", version="0.1.0", lifespan=lifespan)

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(auth.router, prefix="/v1")
    app.include_router(users.router, prefix="/v1")
    app.include_router(admin.router, prefix="/v1")
    app.include_router(jobs.router, prefix="/v1")
    app.include_router(jobs.track_router, prefix="/v1")  # public share-token tracking
    app.include_router(drivers.router, prefix="/v1")
    app.include_router(ws.router)
    return app


app = create_app()
