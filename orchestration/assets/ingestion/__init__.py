"""
Ingestion layer Dagster asset wrappers.
"""

from .haravan import haravan_assets

all_assets = [haravan_assets]

__all__ = ["all_assets", "haravan_assets"]
