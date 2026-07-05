"""Larksuite dlt source package (Bitable, Sheets and Docx via a single YAML catalog)."""

from ingestion.pipelines import build_dlt_pipeline

from .catalog import larksuite_resource_asset_path
from .source import (
    DEFAULT_LARKSUITE_BASE_URL,
    build_larksuite_source,
)

LARKSUITE_PIPELINE_NAME = "larksuite"
LARKSUITE_DATASET_NAME = "raw_larksuite"


def build_larksuite_pipeline(pipeline_name: str = LARKSUITE_PIPELINE_NAME):
    """Build a dlt pipeline instance for Larksuite.

    Args:
        pipeline_name: Name of the dlt pipeline to construct.

    Returns:
        A dlt pipeline configured to load into the Larksuite raw dataset.
    """
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=LARKSUITE_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_LARKSUITE_BASE_URL",
    "LARKSUITE_DATASET_NAME",
    "LARKSUITE_PIPELINE_NAME",
    "build_larksuite_pipeline",
    "build_larksuite_source",
    "larksuite_resource_asset_path",
]
