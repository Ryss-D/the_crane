from typing import Any

import pytest
from fastapi import FastAPI, HTTPException
from httpx import AsyncClient

from app.core import security
from app.core.config import get_settings
from app.core.security import get_token_verifier
from app.models.user import User


async def test_me_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/me")
    assert response.status_code == 401


async def test_me_with_invalid_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/me", headers={"Authorization": "Bearer garbage"})
    assert response.status_code == 401


async def test_me_with_unknown_user_returns_404(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]]
) -> None:
    verified_tokens["valid-token"] = {"uid": "never-synced-uid"}
    response = await client.get("/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 404


async def test_me_with_known_user_returns_200(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["valid-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get("/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(customer_user.id)
    assert body["firebase_uid"] == customer_user.firebase_uid
    assert body["role"] == "customer"


async def test_admin_route_rejects_non_admin_with_403(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    customer_user: User,
) -> None:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    response = await client.get(
        "/v1/admin/ping", headers={"Authorization": "Bearer customer-token"}
    )
    assert response.status_code == 403


async def test_admin_route_allows_admin(
    client: AsyncClient,
    verified_tokens: dict[str, dict[str, Any]],
    admin_user: User,
) -> None:
    verified_tokens["admin-token"] = {"uid": admin_user.firebase_uid}
    response = await client.get("/v1/admin/ping", headers={"Authorization": "Bearer admin-token"})
    assert response.status_code == 200
    assert response.json()["admin"] == admin_user.firebase_uid


# ---- _init_firebase / _verify_firebase_token / get_token_verifier -----------------
#
# These are exercised directly (rather than through the app's `client`, which every
# other test in this file overrides `get_token_verifier` to avoid) because production
# request handling never reaches the real Firebase-backed verifier in this test suite
# otherwise -- `tests/conftest.py`'s `app` fixture always overrides `get_token_verifier`
# with a fake. `fcm_sent` (used by test_push.py/test_ws.py) only exercises
# `_init_firebase`'s early-return branch (by pre-seeding `_firebase_app`), never the
# body that actually talks to firebase_admin.


async def test_init_firebase_without_credentials_raises_503(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(security, "_firebase_app", None)
    # `.env` sets FIREBASE_CREDENTIALS_PATH for local dev -- delenv alone wouldn't
    # un-configure it, since pydantic-settings reads that file regardless of the
    # process environment. An explicit empty string overrides it and is falsy.
    monkeypatch.setenv("FIREBASE_CREDENTIALS_PATH", "")
    get_settings.cache_clear()
    try:
        with pytest.raises(HTTPException) as exc_info:
            security._init_firebase()
        assert exc_info.value.status_code == 503
    finally:
        get_settings.cache_clear()


async def test_init_firebase_initializes_app_when_credentials_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Success path: firebase_admin.initialize_app is called with a Certificate built
    from the configured path, and the result is cached onto the module global."""
    import firebase_admin
    from firebase_admin import credentials

    monkeypatch.setattr(security, "_firebase_app", None)
    monkeypatch.setenv("FIREBASE_CREDENTIALS_PATH", "/fake/firebase-creds.json")
    get_settings.cache_clear()

    fake_cred = object()
    fake_app = object()
    monkeypatch.setattr(credentials, "Certificate", lambda path: fake_cred)  # noqa: ARG005
    monkeypatch.setattr(firebase_admin, "initialize_app", lambda cred: fake_app)  # noqa: ARG005

    try:
        security._init_firebase()
        assert security._firebase_app is fake_app
    finally:
        get_settings.cache_clear()


async def test_verify_firebase_token_returns_verifier_claims(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from firebase_admin import auth

    monkeypatch.setattr(security, "_firebase_app", object())  # already "initialized"
    monkeypatch.setattr(auth, "verify_id_token", lambda token: {"uid": "abc", "token": token})

    claims = security._verify_firebase_token("some-token")
    assert claims == {"uid": "abc", "token": "some-token"}


def test_get_token_verifier_returns_verify_firebase_token() -> None:
    assert security.get_token_verifier() is security._verify_firebase_token


# ---- get_verified_claims edge cases not reachable via the fake_verifier pattern ----


async def test_verifier_raising_http_exception_propagates_unchanged(
    app: FastAPI, client: AsyncClient
) -> None:
    """An HTTPException raised by the verifier itself (e.g. Firebase misconfigured)
    must propagate as-is, not get folded into the generic 401 "Invalid or expired
    token" response the `except Exception` branch produces."""

    def raising_verifier(token: str) -> dict[str, Any]:
        raise HTTPException(status_code=503, detail="Firebase down")

    app.dependency_overrides[get_token_verifier] = lambda: raising_verifier
    response = await client.get("/v1/me", headers={"Authorization": "Bearer whatever"})
    assert response.status_code == 503
    assert response.json()["detail"] == "Firebase down"


async def test_verified_claims_without_uid_or_sub_returns_401(
    client: AsyncClient, verified_tokens: dict[str, dict[str, Any]]
) -> None:
    verified_tokens["no-uid-token"] = {"some": "claim"}
    response = await client.get("/v1/me", headers={"Authorization": "Bearer no-uid-token"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Token has no uid claim"
