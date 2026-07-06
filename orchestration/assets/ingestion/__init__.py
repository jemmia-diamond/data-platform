"""
Ingestion layer Dagster asset wrappers.
"""

from .frappe import frappe_assets
from .google_sheets import google_sheets_assets
from .haravan import haravan_assets
from .nocodb import nocodb_assets
from .pancake import message_jobs_drain, message_jobs_enqueue, pancake_assets

all_assets = [
    haravan_assets,
    frappe_assets,
    nocodb_assets,
    google_sheets_assets,
    pancake_assets,
    message_jobs_enqueue,
    message_jobs_drain,
]

__all__ = [
    "all_assets",
    "frappe_assets",
    "google_sheets_assets",
    "haravan_assets",
    "message_jobs_drain",
    "message_jobs_enqueue",
    "nocodb_assets",
    "pancake_assets",
]
