"""JOB-4 tests: quote endpoint fare math, min-fare floor, caching, directions clients."""

import math
from typing import Any

import pytest
from fastapi import FastAPI, HTTPException
from httpx import AsyncClient

from app.models.user import User
from app.services.pricing import (
    QUOTE_CACHE_PREFIX,
    QUOTE_TTL_SECONDS,
    ROAD_FACTOR,
    GoogleDirectionsClient,
    HaversineFallback,
    get_directions_client,
    haversine_km,
)
from tests.conftest import FakeRedis

MEDELLIN_A = {"lat": 6.2442, "lng": -75.5812}
MEDELLIN_B = {"lat": 6.2000, "lng": -75.5700}

AUTH = {"Authorization": "Bearer customer-token"}


class FixedDirections:
    """Deterministic DirectionsClient for fare-math tests."""

    def __init__(self, km: float) -> None:
        self.km = km

    async def road_distance_km(
        self, pickup: tuple[float, float], dropoff: tuple[float, float]
    ) -> float:
        return self.km


@pytest.fixture
def as_customer(verified_tokens: dict[str, dict[str, Any]], customer_user: User) -> User:
    verified_tokens["customer-token"] = {"uid": customer_user.firebase_uid}
    return customer_user


def _quote_body(vehicle_type: str = "car") -> dict[str, Any]:
    return {"vehicle_type": vehicle_type, "pickup": MEDELLIN_A, "dropoff": MEDELLIN_B}


async def test_quote_requires_auth(client: AsyncClient) -> None:
    response = await client.post("/v1/jobs/quote", json=_quote_body())
    assert response.status_code == 401


async def test_quote_uses_config_values(
    app: FastAPI,
    client: AsyncClient,
    as_customer: User,
    seeded_config: dict[str, Any],
) -> None:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections(10.0)
    response = await client.post("/v1/jobs/quote", headers=AUTH, json=_quote_body("car"))
    assert response.status_code == 200
    body = response.json()
    # car: 60000 base + 5000/km x 10 km = 110000, above the 80000 floor.
    assert body["price"] == 110000
    assert body["distance_km"] == 10.0
    assert body["eta_minutes"] == math.ceil(10.0 / 28 * 60)
    assert body["vehicle_type"] == "car"
    assert body["quote_id"]


async def test_quote_floors_at_min_fare(
    app: FastAPI,
    client: AsyncClient,
    as_customer: User,
    seeded_config: dict[str, Any],
) -> None:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections(1.0)
    response = await client.post("/v1/jobs/quote", headers=AUTH, json=_quote_body("car"))
    assert response.status_code == 200
    # 60000 + 5000 x 1 = 65000 -> floored at the configured 80000 min fare.
    assert response.json()["price"] == 80000


async def test_quote_is_cached_with_ttl(
    app: FastAPI,
    client: AsyncClient,
    fake_redis: FakeRedis,
    as_customer: User,
    seeded_config: dict[str, Any],
) -> None:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections(5.0)
    response = await client.post("/v1/jobs/quote", headers=AUTH, json=_quote_body("moto"))
    assert response.status_code == 200
    key = QUOTE_CACHE_PREFIX + response.json()["quote_id"]
    assert key in fake_redis.store
    assert fake_redis.ttls[key] == QUOTE_TTL_SECONDS


async def test_quote_without_pricing_config_is_503(
    app: FastAPI, client: AsyncClient, as_customer: User
) -> None:
    app.dependency_overrides[get_directions_client] = lambda: FixedDirections(5.0)
    response = await client.post("/v1/jobs/quote", headers=AUTH, json=_quote_body())
    assert response.status_code == 503


async def test_haversine_fallback_applies_road_factor() -> None:
    a = (MEDELLIN_A["lat"], MEDELLIN_A["lng"])
    b = (MEDELLIN_B["lat"], MEDELLIN_B["lng"])
    straight = haversine_km(a, b)
    assert 4 < straight < 6  # ~5 km apart in Medellín
    assert await HaversineFallback().road_distance_km(a, b) == pytest.approx(straight * ROAD_FACTOR)
    assert haversine_km(a, a) == 0


async def test_default_directions_client_is_haversine_without_key() -> None:
    # Settings in tests carry no google_maps_api_key -> automatic fallback.
    assert isinstance(get_directions_client(), HaversineFallback)


async def test_google_client_without_key_raises_503() -> None:
    with pytest.raises(HTTPException) as exc_info:
        await GoogleDirectionsClient(None).road_distance_km((6.24, -75.58), (6.20, -75.57))
    assert exc_info.value.status_code == 503
