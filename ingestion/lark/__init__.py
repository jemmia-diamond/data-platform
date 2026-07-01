"""Lark Bitable dlt source package."""

from ingestion.pipelines import build_dlt_pipeline

from .source import (
    DEFAULT_LARK_BASE_URL,
    build_lark_source,
)

LARK_PIPELINE_NAME = "lark"
LARK_DATASET_NAME = "raw_lark"


def build_lark_pipeline(pipeline_name: str = LARK_PIPELINE_NAME):
    """Build a dlt pipeline instance for Lark.

    Args:
        pipeline_name: Name of the dlt pipeline to construct.

    Returns:
        A dlt pipeline configured to load into the Lark raw dataset.
    """
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=LARK_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_LARK_BASE_URL",
    "LARK_DATASET_NAME",
    "LARK_PIPELINE_NAME",
    "build_lark_pipeline",
    "build_lark_source",
]
