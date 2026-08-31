"""Tests for the Places/Directions proxy endpoints (FND-6 follow-up):
/v1/places/autocomplete, /v1/places/details/{id}, /v1/directions/route.
"""

from typing import Any

import pytest
from fastapi import FastAPI, HTTPException
from httpx import AsyncClient

from app.models.user import User
from app.services.pricing import GoogleDirectionsClient, HaversineFallback, get_directions_client

AUTH = {"Authorization": "Bearer customer-token"}


@pytest.fixture
def as_customer(verified_tokens: dict[str, dict[str, Any]], customer_user: User) -> User:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    return customer_user


class _FakeGoogleResponse:
    """Stand-in for httpx.Response — just the two attributes the real clients read."""

    def __init__(self, status_code: int, payload: dict[str, Any]) -> None:
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict[str, Any]:
        return self._payload


class _FakeGoogleAsyncClient:
    """Stand-in for httpx.AsyncClient — never hits the network."""

    def __init__(self, response: _FakeGoogleResponse, **_: Any) -> None:
        self._response = response

    def __call__(self, **_: Any) -> "_FakeGoogleAsyncClient":
        return self

    async def __aenter__(self) -> "_FakeGoogleAsyncClient":
        return self

    async def __aexit__(self, *exc: Any) -> None:
        return None

    async def get(self, *args: Any, **kwargs: Any) -> _FakeGoogleResponse:
        return self._response


def _patch_places_response(
    monkeypatch: pytest.MonkeyPatch, response: _FakeGoogleResponse
) -> None:
    monkeypatch.setattr("app.services.places.httpx.AsyncClient", _FakeGoogleAsyncClient(response))


def _patch_directions_response(
    monkeypatch: pytest.MonkeyPatch, response: _FakeGoogleResponse
) -> None:
    monkeypatch.setattr(
        "app.services.pricing.httpx.AsyncClient", _FakeGoogleAsyncClient(response)
    )


def _configure_key(monkeypatch: pytest.MonkeyPatch, key: str = "fake-key") -> None:
    class _FakeSettings:
        google_maps_api_key = key

    monkeypatch.setattr("app.services.places.get_settings", lambda: _FakeSettings())


# --- autocomplete -----------------------------------------------------------


async def test_autocomplete_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/v1/places/autocomplete", params={"input": "El Poblado"})
    assert response.status_code == 401


async def test_autocomplete_without_key_returns_empty_predictions(
    client: AsyncClient, as_customer: User
) -> None:
    response = await client.get(
        "/v1/places/autocomplete", headers=AUTH, params={"input": "El Poblado"}
    )
    assert response.status_code == 200
    assert response.json() == {"predictions": []}


async def test_autocomplete_with_key_returns_real_predictions(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(
        monkeypatch,
        _FakeGoogleResponse(
            200,
            {
                "status": "OK",
                "predictions": [
                    {"place_id": "abc123", "description": "El Poblado, Medellín"}
                ],
            },
        ),
    )
    response = await client.get(
        "/v1/places/autocomplete", headers=AUTH, params={"input": "El Poblado"}
    )
    assert response.status_code == 200
    assert response.json() == {
        "predictions": [{"place_id": "abc123", "description": "El Poblado, Medellín"}]
    }


async def test_autocomplete_non_ok_status_returns_empty(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(monkeypatch, _FakeGoogleResponse(200, {"status": "REQUEST_DENIED"}))
    response = await client.get("/v1/places/autocomplete", headers=AUTH, params={"input": "x"})
    assert response.status_code == 200
    assert response.json() == {"predictions": []}


# --- details ------------------------------------------------------------


async def test_details_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/v1/places/details/abc123")
    assert response.status_code == 401


async def test_details_without_key_is_503(client: AsyncClient, as_customer: User) -> None:
    response = await client.get("/v1/places/details/some-place-id", headers=AUTH)
    assert response.status_code == 503


async def test_details_with_key_returns_location(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(
        monkeypatch,
        _FakeGoogleResponse(
            200,
            {
                "status": "OK",
                "result": {
                    "geometry": {"location": {"lat": 6.2442, "lng": -75.5812}},
                    "formatted_address": "El Poblado, Medellín, Colombia",
                },
            },
        ),
    )
    response = await client.get("/v1/places/details/abc123", headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {
        "lat": 6.2442,
        "lng": -75.5812,
        "formatted_address": "El Poblado, Medellín, Colombia",
    }


async def test_details_non_ok_status_is_503(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(monkeypatch, _FakeGoogleResponse(200, {"status": "NOT_FOUND"}))
    response = await client.get("/v1/places/details/bad-id", headers=AUTH)
    assert response.status_code == 503


# --- route --------------------------------------------------------------

_ROUTE_PARAMS = {
    "origin_lat": 6.24,
    "origin_lng": -75.58,
    "dest_lat": 6.20,
    "dest_lng": -75.57,
}


async def test_route_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/v1/directions/route", params=_ROUTE_PARAMS)
    assert response.status_code == 401


async def test_route_without_key_is_503(client: AsyncClient, as_customer: User) -> None:
    response = await client.get("/v1/directions/route", headers=AUTH, params=_ROUTE_PARAMS)
    assert response.status_code == 503


async def test_route_with_key_returns_decoded_polyline(
    app: FastAPI, client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Google's own canonical polyline-algorithm example: encodes
    # [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)].
    payload = {
        "status": "OK",
        "routes": [
            {
                "legs": [{"distance": {"value": 1000}}],
                "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
            }
        ],
    }
    _patch_directions_response(monkeypatch, _FakeGoogleResponse(200, payload))
    app.dependency_overrides[get_directions_client] = lambda: GoogleDirectionsClient("fake-key")
    try:
        response = await client.get(
            "/v1/directions/route", headers=AUTH, params=_ROUTE_PARAMS
        )
    finally:
        del app.dependency_overrides[get_directions_client]

    assert response.status_code == 200
    points = response.json()["points"]
    assert points[0] == pytest.approx({"lat": 38.5, "lng": -120.2}, abs=1e-4)
    assert points[-1] == pytest.approx({"lat": 43.252, "lng": -126.453}, abs=1e-4)


async def test_route_non_ok_status_is_503(
    app: FastAPI, client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_directions_response(
        monkeypatch, _FakeGoogleResponse(200, {"status": "ZERO_RESULTS", "routes": []})
    )
    app.dependency_overrides[get_directions_client] = lambda: GoogleDirectionsClient("fake-key")
    try:
        response = await client.get(
            "/v1/directions/route", headers=AUTH, params=_ROUTE_PARAMS
        )
    finally:
        del app.dependency_overrides[get_directions_client]
    assert response.status_code == 503


async def test_haversine_fallback_route_polyline_raises_503() -> None:
    with pytest.raises(HTTPException) as exc_info:
        await HaversineFallback().route_polyline((6.24, -75.58), (6.20, -75.57))
    assert exc_info.value.status_code == 503


# --- geocode --------------------------------------------------------------

_GEOCODE_PARAMS = {"lat": 6.2442, "lng": -75.5812}


async def test_geocode_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/v1/places/geocode", params=_GEOCODE_PARAMS)
    assert response.status_code == 401


async def test_geocode_without_key_is_503(client: AsyncClient, as_customer: User) -> None:
    response = await client.get("/v1/places/geocode", headers=AUTH, params=_GEOCODE_PARAMS)
    assert response.status_code == 503


async def test_geocode_with_key_returns_address(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(
        monkeypatch,
        _FakeGoogleResponse(
            200,
            {
                "status": "OK",
                "results": [{"formatted_address": "El Poblado, Medellín, Colombia"}],
            },
        ),
    )
    response = await client.get("/v1/places/geocode", headers=AUTH, params=_GEOCODE_PARAMS)
    assert response.status_code == 200
    assert response.json() == {"address": "El Poblado, Medellín, Colombia"}


async def test_geocode_non_ok_status_is_503(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(monkeypatch, _FakeGoogleResponse(200, {"status": "ZERO_RESULTS"}))
    response = await client.get("/v1/places/geocode", headers=AUTH, params=_GEOCODE_PARAMS)
    assert response.status_code == 503


async def test_geocode_zero_results_status_ok_but_empty_is_503(
    client: AsyncClient, as_customer: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    _configure_key(monkeypatch)
    _patch_places_response(monkeypatch, _FakeGoogleResponse(200, {"status": "OK", "results": []}))
    response = await client.get("/v1/places/geocode", headers=AUTH, params=_GEOCODE_PARAMS)
    assert response.status_code == 503
