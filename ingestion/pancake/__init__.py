"""
Pancake dlt source package.
"""

from ingestion.pipelines import build_dlt_pipeline

from .source import (
    DEFAULT_START_DATE,
    build_pancake_source,
)

PANCAKE_PIPELINE_NAME = "pancake"
PANCAKE_DATASET_NAME = "raw_pancake"


def build_pancake_pipeline(pipeline_name: str = PANCAKE_PIPELINE_NAME):
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=PANCAKE_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_START_DATE",
    "PANCAKE_DATASET_NAME",
    "PANCAKE_PIPELINE_NAME",
    "build_pancake_pipeline",
    "build_pancake_source",
]
