"""Pricing service — filled by JOB-4.

Will compute quotes (`base + per_km × road_distance_km`, min fare, COP) from live
platform_config values and Google Directions distances, with short-lived quote caching.
"""
