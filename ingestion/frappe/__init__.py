"""
Frappe (ERPNext) dlt source package.
"""

from ingestion.pipelines import build_dlt_pipeline

from .source import DEFAULT_FRAPPE_BASE_URL, DEFAULT_START_DATE, build_frappe_source

FRAPPE_PIPELINE_NAME = "frappe"
FRAPPE_DATASET_NAME = "raw_frappe"


def build_frappe_pipeline(pipeline_name: str = FRAPPE_PIPELINE_NAME):
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=FRAPPE_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_FRAPPE_BASE_URL",
    "DEFAULT_START_DATE",
    "FRAPPE_DATASET_NAME",
    "FRAPPE_PIPELINE_NAME",
    "build_frappe_pipeline",
    "build_frappe_source",
]
