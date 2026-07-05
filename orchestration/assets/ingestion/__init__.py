"""
Ingestion layer Dagster asset wrappers.
"""

from .frappe import frappe_assets
from .google_sheets import google_sheets_assets
from .haravan import haravan_assets
from .larksuite import larksuite_assets
from .nocodb import nocodb_assets
from .openfacet import openfacet_assets
from .pancake import pancake_assets, pancake_backfill_assets

all_assets = [
    haravan_assets,
    frappe_assets,
    nocodb_assets,
    google_sheets_assets,
    openfacet_assets,
    pancake_assets,
    pancake_backfill_assets,
    larksuite_assets,
]

__all__ = [
    "all_assets",
    "frappe_assets",
    "google_sheets_assets",
    "haravan_assets",
    "larksuite_assets",
    "nocodb_assets",
    "openfacet_assets",
    "pancake_assets",
    "pancake_backfill_assets",
]

