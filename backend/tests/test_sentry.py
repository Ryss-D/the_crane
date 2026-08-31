"""OPS-6: Sentry wiring in app/main.py's create_app.

No real Sentry account/DSN exists yet (see backend/.env.example's SENTRY_DSN
comment), so these tests only cover the no-DSN no-op path (the only one this repo
can actually exercise) plus the guard's opposite branch -- that `sentry_sdk.init`
is called, with the right args, only when a DSN is actually configured. Real event
capture against a live DSN is out of scope, same as GOOGLE_MAPS_API_KEY/WOMPI_*'s
own credential-gated tests elsewhere in this suite.
"""

from typing import Any

import pytest

import app.main as main_module
from app.core.config import get_settings


def test_app_boots_with_no_sentry_dsn_configured() -> None:
    """sentry_dsn=None is this repo's real default -- create_app() must not raise,
    and must not touch sentry_sdk.init at all (not even with an empty/None dsn)."""
    assert get_settings().sentry_dsn is None  # the default this test relies on

    calls: list[Any] = []

    def fake_init(*args: Any, **kwargs: Any) -> None:
        calls.append((args, kwargs))

    import sentry_sdk

    original_init = sentry_sdk.init
    sentry_sdk.init = fake_init  # type: ignore[assignment]
    try:
        app = main_module.create_app()
    finally:
        sentry_sdk.init = original_init  # type: ignore[assignment]

    assert app is not None
    assert calls == []  # init must never be called when sentry_dsn is unset


def test_create_app_initializes_sentry_when_dsn_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The opposite branch: a configured DSN does trigger exactly one init() call,
    with that DSN passed through. sentry_sdk.init itself is monkeypatched out so
    this never attempts a real network call to a fake DSN."""
    monkeypatch.setenv("SENTRY_DSN", "https://fake-key@fake.ingest.sentry.io/1234")
    get_settings.cache_clear()
    try:
        assert get_settings().sentry_dsn == "https://fake-key@fake.ingest.sentry.io/1234"

        calls: list[Any] = []
        monkeypatch.setattr(
            main_module.sentry_sdk, "init", lambda **kwargs: calls.append(kwargs)
        )

        app = main_module.create_app()

        assert app is not None
        assert len(calls) == 1
        assert calls[0]["dsn"] == "https://fake-key@fake.ingest.sentry.io/1234"
    finally:
        get_settings.cache_clear()
