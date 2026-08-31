"""Places Autocomplete/Details + Directions route proxy (FND-6 follow-up):
server-side only, via settings.google_maps_api_key -- mirrors
app/services/pricing.py's GoogleDirectionsClient reasoning exactly. Android/iOS
app-restricted client keys don't work for raw REST calls, so these three
endpoints exist precisely so no client app ever needs a Places-or-Directions-
capable key of its own; they just call the authenticated backend instead.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import CurrentUser
from app.schemas.places import (
    GeocodeResponse,
    PlaceAutocompleteResponse,
    PlaceDetailsResponse,
    RouteResponse,
)
from app.services import places as places_service
from app.services.pricing import DirectionsClient, get_directions_client

router = APIRouter(prefix="/places", tags=["places"])
directions_router = APIRouter(prefix="/directions", tags=["places"])

DirectionsDep = Annotated[DirectionsClient, Depends(get_directions_client)]


@router.get("/autocomplete", response_model=PlaceAutocompleteResponse)
async def autocomplete(
    user: CurrentUser,
    query: Annotated[str, Query(alias="input", min_length=1)],
) -> dict[str, list[dict[str, str]]]:
    return {"predictions": await places_service.autocomplete(query)}


@router.get("/details/{place_id}", response_model=PlaceDetailsResponse)
async def place_details(place_id: str, user: CurrentUser) -> dict[str, object]:
    return await places_service.place_details(place_id)


@router.get("/geocode", response_model=GeocodeResponse)
async def geocode(lat: float, lng: float, user: CurrentUser) -> dict[str, str]:
    address = await places_service.reverse_geocode(lat, lng)
    if address is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Geocoding service unavailable",
        )
    return {"address": address}


@directions_router.get("/route", response_model=RouteResponse)
async def route(
    user: CurrentUser,
    directions: DirectionsDep,
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict[str, list[dict[str, float]]]:
    points = await directions.route_polyline((origin_lat, origin_lng), (dest_lat, dest_lng))
    return {"points": [{"lat": lat, "lng": lng} for lat, lng in points]}
