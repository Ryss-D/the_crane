"""Schemas for the Places/Directions proxy endpoints (app/api/places.py, FND-6
follow-up).
"""

from pydantic import BaseModel

from app.schemas.job import LatLng


class PlacePrediction(BaseModel):
    place_id: str
    description: str


class PlaceAutocompleteResponse(BaseModel):
    predictions: list[PlacePrediction]


class PlaceDetailsResponse(LatLng):
    formatted_address: str


class RouteResponse(BaseModel):
    points: list[LatLng]


class GeocodeResponse(BaseModel):
    address: str
