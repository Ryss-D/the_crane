"""TRK-3: send_push (app/services/push.py) unit tests.

Never touches the real Firebase API -- firebase_admin.messaging.send is mocked via
the `fcm_sent` fixture (tests/conftest.py), which also fakes Firebase Admin looking
"configured" by monkeypatching app.core.security's already-initialized-app check.
"""

from typing import Any

import pytest

from app.services.push import send_push


async def test_send_push_noop_without_token(fcm_sent: list[Any]) -> None:
    """No fcm_token on the user -> no push attempt (not an error)."""
    await send_push("", {"type": "job_event", "job_id": "abc"})
    assert fcm_sent == []


async def test_send_push_noop_when_firebase_not_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """No FIREBASE_CREDENTIALS_PATH -> no push attempt (not an error), mirroring
    app/core/security.py treating that as a valid "not configured yet" state."""
    import firebase_admin.messaging as messaging

    calls: list[Any] = []
    monkeypatch.setattr(messaging, "send", lambda *a, **kw: calls.append((a, kw)))

    await send_push("some-token", {"type": "job_event", "job_id": "abc"})

    assert calls == []


async def test_send_push_sends_data_only_message_when_configured(
    fcm_sent: list[Any],
) -> None:
    await send_push("driver-fcm-token", {"type": "job_offer", "job_id": "job-1"})

    assert len(fcm_sent) == 1
    message = fcm_sent[0]
    assert message.token == "driver-fcm-token"
    assert message.data == {"type": "job_offer", "job_id": "job-1"}
    assert message.notification is None  # data-only -- no notification block


async def test_send_push_swallows_send_errors(
    fcm_sent: list[Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    """A raised SDK/network error from firebase_admin.messaging.send must not
    propagate -- push sending is best-effort and must never break the
    job-transition/dispatch flow that triggers it."""
    import firebase_admin.messaging as messaging

    def boom(*_args: Any, **_kwargs: Any) -> str:
        raise RuntimeError("FCM unreachable")

    monkeypatch.setattr(messaging, "send", boom)

    await send_push("driver-fcm-token", {"type": "job_offer", "job_id": "job-1"})  # no raise
