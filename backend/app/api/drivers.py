"""Drivers router — pre-registered in main.py; routes are filled by AUTH-5/DRV/DSP tasks."""

from fastapi import APIRouter

router = APIRouter(prefix="/drivers", tags=["drivers"])
