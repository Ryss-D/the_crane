"""Dispatch / matching service — filled by DSP-2.

Will run the sequential-offer loop: Redis geo search for available drivers, capacity
filtering via trucks, offer TTL handling, radius widening, and job_offers audit rows.
"""
