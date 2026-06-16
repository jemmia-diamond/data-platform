"""Contains source, helper functions and default configuration for ingesting Google Sheets."""
from ingestion.pipelines import build_dlt_pipeline

from .source import (
    DEFAULT_SHEET_SPECS,
    SheetSpec,
    build_google_sheets_source,
    google_sheets_source,
)

GOOGLE_SHEETS_PIPELINE_NAME = "google_sheets"
GOOGLE_SHEETS_DATASET_NAME = "raw_google_sheets"


def build_google_sheets_pipeline(pipeline_name: str = GOOGLE_SHEETS_PIPELINE_NAME):
    """Build a dlt pipeline instance for Google Sheets."""
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=GOOGLE_SHEETS_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_SHEET_SPECS",
    "GOOGLE_SHEETS_DATASET_NAME",
    "GOOGLE_SHEETS_PIPELINE_NAME",
    "SheetSpec",
    "build_google_sheets_pipeline",
    "build_google_sheets_source",
    "google_sheets_source",
]
