"""
Ingestion layer Dagster asset wrappers.
"""

from .frappe import frappe_assets
from .google_sheets import google_sheets_assets
from .haravan import haravan_assets
from .lark import lark_assets
from .nocodb import nocodb_assets
from .pancake import pancake_assets, pancake_backfill_assets

all_assets = [
    haravan_assets,
    frappe_assets,
    nocodb_assets,
    google_sheets_assets,
    pancake_assets,
    pancake_backfill_assets,
    lark_assets,
]

__all__ = [
    "all_assets",
    "frappe_assets",
    "google_sheets_assets",
    "haravan_assets",
    "lark_assets",
    "nocodb_assets",
    "pancake_assets",
    "pancake_backfill_assets",
]

