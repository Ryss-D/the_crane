"""Pricing service (JOB-4): road distance -> config-driven fare -> cached quote.

`fare = base + per_km x road_distance_km`, floored at the per-type min fare, in
COP (PLAN §2.5). Road distance comes from an injectable DirectionsClient: the
real Google Directions implementation when `settings.google_maps_api_key` is
set, otherwise an automatic haversine fallback (straight-line km x 1.3 road
factor) used by tests and local dev. Quotes are cached in Redis for 10 minutes
under a quote_id; POST /v1/jobs consumes them single-use.
"""

import json
import logging
import math
import uuid
from typing import Any, Protocol

import httpx
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.job import VehicleType
from app.services.config import RedisLike, get_config

logger = logging.getLogger(__name__)

QUOTE_CACHE_PREFIX = "quote:"
QUOTE_TTL_SECONDS = 600
ETA_SPEED_KMH = 28  # city tow-truck drive-time heuristic
ROAD_FACTOR = 1.3  # straight-line -> road distance multiplier for the fallback

LatLng = tuple[float, float]


class DirectionsClient(Protocol):
    """The slice of a directions provider pricing needs (injected, overridable in tests)."""

    async def road_distance_km(self, pickup: LatLng, dropoff: LatLng) -> float: ...


class GoogleDirectionsClient:
    """Road distance via the Google Directions API (needs settings.google_maps_api_key)."""

    BASE_URL = "https://maps.googleapis.com/maps/api/directions/json"

    def __init__(self, api_key: str | None) -> None:
        self.api_key = api_key

    async def road_distance_km(self, pickup: LatLng, dropoff: LatLng) -> float:
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="google_maps_api_key is not configured",
            )
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                self.BASE_URL,
                params={
                    "origin": f"{pickup[0]},{pickup[1]}",
                    "destination": f"{dropoff[0]},{dropoff[1]}",
                    "key": self.api_key,
                },
            )
        data = response.json() if response.status_code == 200 else {}
        routes = data.get("routes") or []
        if data.get("status") != "OK" or not routes:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Directions service unavailable",
            )
        meters = sum(leg["distance"]["value"] for leg in routes[0]["legs"])
        return meters / 1000


class HaversineFallback:
    """Straight-line distance x ROAD_FACTOR — tests, local dev, and the no-key fallback."""

    async def road_distance_km(self, pickup: LatLng, dropoff: LatLng) -> float:
        return haversine_km(pickup, dropoff) * ROAD_FACTOR


def haversine_km(a: LatLng, b: LatLng) -> float:
    """Great-circle distance in km between two (lat, lng) points."""
    earth_radius_km = 6371.0
    phi1, phi2 = math.radians(a[0]), math.radians(b[0])
    dphi = math.radians(b[0] - a[0])
    dlambda = math.radians(b[1] - a[1])
    h = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * earth_radius_km * math.asin(math.sqrt(h))


def get_directions_client() -> DirectionsClient:
    """Dependency: Google Directions when a key is configured, haversine otherwise."""
    if get_settings().google_maps_api_key:
        return GoogleDirectionsClient(get_settings().google_maps_api_key)
    logger.warning(
        "google_maps_api_key not set — using haversine x %.1f road-distance fallback",
        ROAD_FACTOR,
    )
    return HaversineFallback()


async def build_quote(
    session: AsyncSession,
    redis: RedisLike,
    directions: DirectionsClient,
    *,
    vehicle_type: VehicleType,
    pickup: LatLng,
    dropoff: LatLng,
) -> dict[str, Any]:
    """Price a trip from live pricing config and cache it for QUOTE_TTL_SECONDS."""
    pricing = await get_config(session, redis, "pricing") or {}
    type_config = pricing.get(vehicle_type.value)
    if type_config is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"No pricing configured for vehicle type '{vehicle_type.value}'",
        )

    distance_km = await directions.road_distance_km(pickup, dropoff)
    fare = round(type_config["base"] + type_config["per_km"] * distance_km)
    price = max(fare, int(type_config["min"]))
    eta_minutes = max(1, math.ceil(distance_km / ETA_SPEED_KMH * 60))

    quote = {
        "quote_id": str(uuid.uuid4()),
        "vehicle_type": vehicle_type.value,
        "price": price,
        "distance_km": round(distance_km, 2),
        "eta_minutes": eta_minutes,
    }
    await redis.set(QUOTE_CACHE_PREFIX + quote["quote_id"], json.dumps(quote), ex=QUOTE_TTL_SECONDS)
    return quote


async def pop_quote(redis: RedisLike, quote_id: uuid.UUID | str) -> dict[str, Any] | None:
    """Fetch-and-consume a cached quote; None when unknown or expired (TTL lapsed)."""
    key = QUOTE_CACHE_PREFIX + str(quote_id)
    raw = await redis.get(key)
    if raw is None:
        return None
    await redis.delete(key)  # single-use: one job per quote
    return json.loads(raw)
