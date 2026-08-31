"""Places Autocomplete/Details proxy (FND-6 follow-up): server-side only, via
settings.google_maps_api_key -- mirrors app/services/pricing.py's
GoogleDirectionsClient reasoning exactly. Android/iOS app-restricted client keys
only work through the native Maps SDK's own attestation, not a plain REST call
made from Dart/JS code, so these two functions exist precisely so no client app
ever needs a Places-capable key of its own.

Autocomplete degrades to an empty result set (never an error) when no key is
configured or Google returns anything but OK/ZERO_RESULTS -- a client with no
predictions just falls back to manual text entry, same "never hard-fail on a
best-effort enrichment" stance as pricing.py's haversine fallback. Details has
no such fallback (there's nothing sensible to return instead of real
coordinates for a specific place_id), so it 503s instead, same shape
GoogleDirectionsClient(None) uses for a missing key.
"""

import logging
from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import get_settings

logger = logging.getLogger(__name__)

# Valle de Aburrá bias for autocomplete -- same anchor point used throughout
# this codebase (e.g. the Flutter app's fakeGeocode, request_bloc.dart).
MEDELLIN_LAT = 6.2442
MEDELLIN_LNG = -75.5812
AUTOCOMPLETE_RADIUS_METERS = 20_000

AUTOCOMPLETE_URL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"


async def autocomplete(query: str) -> list[dict[str, str]]:
    api_key = get_settings().google_maps_api_key
    if not api_key:
        logger.warning("google_maps_api_key not set — autocomplete returns no predictions")
        return []
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            AUTOCOMPLETE_URL,
            params={
                "input": query,
                "key": api_key,
                "location": f"{MEDELLIN_LAT},{MEDELLIN_LNG}",
                "radius": AUTOCOMPLETE_RADIUS_METERS,
                "components": "country:co",
                "language": "es",
            },
        )
    data = response.json() if response.status_code == 200 else {}
    if data.get("status") not in ("OK", "ZERO_RESULTS"):
        logger.warning("Places autocomplete non-OK status: %s", data.get("status"))
        return []
    return [
        {"place_id": prediction["place_id"], "description": prediction["description"]}
        for prediction in data.get("predictions", [])
    ]


async def place_details(place_id: str) -> dict[str, Any]:
    api_key = get_settings().google_maps_api_key
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="google_maps_api_key is not configured",
        )
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            DETAILS_URL,
            params={
                "place_id": place_id,
                "fields": "geometry,formatted_address",
                "key": api_key,
            },
        )
    data = response.json() if response.status_code == 200 else {}
    result = data.get("result")
    if data.get("status") != "OK" or not result:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Places service unavailable",
        )
    location = result["geometry"]["location"]
    return {
        "lat": location["lat"],
        "lng": location["lng"],
        "formatted_address": result.get("formatted_address", ""),
    }
