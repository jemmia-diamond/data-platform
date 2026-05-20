from ingestion.pipelines import build_dlt_pipeline

from .source import (
    DEFAULT_NOCODB_BASE_URL,
    DEFAULT_START_DATE,
    build_nocodb_source,
)

NOCODB_PIPELINE_NAME = "nocodb"
NOCODB_DATASET_NAME = "raw_nocodb"


def build_nocodb_pipeline(pipeline_name: str = NOCODB_PIPELINE_NAME):
    """Build a dlt pipeline instance for NocoDB."""
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=NOCODB_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_NOCODB_BASE_URL",
    "DEFAULT_START_DATE",
    "NOCODB_DATASET_NAME",
    "NOCODB_PIPELINE_NAME",
    "build_nocodb_pipeline",
    "build_nocodb_source",
]
