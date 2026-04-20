"""
Haravan dlt source package.
"""

from ingestion.pipelines import build_dlt_pipeline

from .source import DEFAULT_HARAVAN_BASE_URL, DEFAULT_START_DATE, build_haravan_source

HARAVAN_PIPELINE_NAME = "haravan"
HARAVAN_DATASET_NAME = "raw_haravan"


def build_haravan_pipeline():
    return build_dlt_pipeline(
        connector_name=HARAVAN_PIPELINE_NAME,
        dataset_name=HARAVAN_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_HARAVAN_BASE_URL",
    "DEFAULT_START_DATE",
    "HARAVAN_DATASET_NAME",
    "HARAVAN_PIPELINE_NAME",
    "build_haravan_pipeline",
    "build_haravan_source",
]
