"""
MISA (AMIS ACT Open API) dlt source package.
"""

from ingestion.pipelines import build_dlt_pipeline

from .source import DEFAULT_MISA_BASE_URL, build_misa_source

MISA_PIPELINE_NAME = "misa"
MISA_DATASET_NAME = "raw_misa"


def build_misa_pipeline(pipeline_name: str = MISA_PIPELINE_NAME):
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=MISA_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_MISA_BASE_URL",
    "MISA_DATASET_NAME",
    "MISA_PIPELINE_NAME",
    "build_misa_pipeline",
    "build_misa_source",
]
