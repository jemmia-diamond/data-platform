"""
Assets module - All Dagster assets organized by layer
"""

from .ingestion import all_assets as ingestion_assets
from .transformation import all_assets as transformation_assets

all_assets = transformation_assets + ingestion_assets

__all__ = ["all_assets"]
