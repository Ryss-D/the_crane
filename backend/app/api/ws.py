"""WebSocket router — pre-registered in main.py; endpoints are filled by RT (realtime) tasks."""

from fastapi import APIRouter

router = APIRouter(prefix="/ws", tags=["ws"])
