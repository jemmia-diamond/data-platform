"""
Ingestion layer Dagster asset wrappers.
"""

from .haravan import haravan_assets
from .frappe import frappe_assets
from .nocodb import nocodb_assets
from .google_sheets import google_sheets_assets

all_assets = [haravan_assets, frappe_assets, nocodb_assets, google_sheets_assets]

__all__ = [
    "all_assets",
    "haravan_assets",
    "frappe_assets",
    "nocodb_assets",
    "google_sheets_assets",
]

