"""
Ingestion layer Dagster asset wrappers.
"""

from .frappe import frappe_assets
from .google_sheets import google_sheets_assets
from .haravan import haravan_assets, inventory_locations_balance_daily_snapshot
from .larksuite import larksuite_assets
from .nocodb import nocodb_assets
from .openfacet import openfacet_assets
from .pancake import (
    message_jobs_drain,
    message_jobs_enqueue,
    message_jobs_refresh_edits,
    pancake_assets,
    pancake_conversations_backfill,
)

all_assets = [
    haravan_assets,
    inventory_locations_balance_daily_snapshot,
    frappe_assets,
    nocodb_assets,
    google_sheets_assets,
    openfacet_assets,
    pancake_assets,
    larksuite_assets,
    message_jobs_enqueue,
    message_jobs_drain,
    message_jobs_refresh_edits,
    pancake_conversations_backfill,
]

__all__ = [
    "all_assets",
    "frappe_assets",
    "google_sheets_assets",
    "haravan_assets",
    "inventory_locations_balance_daily_snapshot",
    "larksuite_assets",
    "message_jobs_drain",
    "message_jobs_enqueue",
    "message_jobs_refresh_edits",
    "nocodb_assets",
    "openfacet_assets",
    "pancake_assets",
    "pancake_conversations_backfill",
]
