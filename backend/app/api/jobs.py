"""Jobs router — pre-registered in main.py; routes are filled by JOB-4/JOB-5/JOB-6."""

from fastapi import APIRouter

router = APIRouter(prefix="/jobs", tags=["jobs"])
