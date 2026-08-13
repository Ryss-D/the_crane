"""app/main.py's `lifespan`: the DSP-4 offer-expiry worker start/cancel dance around
the ASGI app's lifecycle.

Every other test in this suite talks to the app through ASGITransport, which (per
app/main.py's own comment) never runs lifespan at all -- so `lifespan` itself is
otherwise never exercised. It's testable without live infra by entering/exiting it
directly as the async context manager it is, with `run_offer_expiry_worker` swapped
for a fake that never touches a real DB/Redis connection (the worker's own body doing
that is a separate concern, already out of scope for a lifespan test).
"""

import asyncio

import pytest

import app.main as main_module
from app.core.config import get_settings


async def test_lifespan_starts_and_cleanly_cancels_worker_when_enabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert get_settings().enable_workers is True  # the default this test relies on

    started = asyncio.Event()
    cancelled = asyncio.Event()

    async def fake_worker(sessionmaker: object, redis_client: object) -> None:
        started.set()
        try:
            await asyncio.sleep(100)
        except asyncio.CancelledError:
            cancelled.set()
            raise

    monkeypatch.setattr(main_module, "run_offer_expiry_worker", fake_worker)

    app = main_module.create_app()
    async with main_module.lifespan(app):
        await asyncio.wait_for(started.wait(), timeout=1)
    # By the time `async with` has exited, lifespan already awaited the cancelled
    # task (its own `with contextlib.suppress(asyncio.CancelledError): await
    # worker_task`), so this is already set -- no extra wait needed.
    assert cancelled.is_set()


async def test_lifespan_skips_worker_when_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    """The `enable_workers=False` branch: `worker_task` stays None, so the shutdown
    half has nothing to cancel -- only dispose_engine/close_redis run."""
    monkeypatch.setenv("ENABLE_WORKERS", "false")
    get_settings.cache_clear()
    try:
        assert get_settings().enable_workers is False

        async def failing_worker(sessionmaker: object, redis_client: object) -> None:
            raise AssertionError("run_offer_expiry_worker must not be started")

        monkeypatch.setattr(main_module, "run_offer_expiry_worker", failing_worker)

        app = main_module.create_app()
        async with main_module.lifespan(app):
            pass  # no exception -> the disabled branch was taken cleanly
    finally:
        get_settings.cache_clear()
