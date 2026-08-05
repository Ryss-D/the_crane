from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import admin, users
from app.core.database import dispose_engine


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    yield
    await dispose_engine()


def create_app() -> FastAPI:
    app = FastAPI(title="The Crane API", version="0.1.0", lifespan=lifespan)

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(users.router, prefix="/v1")
    app.include_router(admin.router, prefix="/v1")
    return app


app = create_app()
