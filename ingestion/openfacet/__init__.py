from ingestion.pipelines import build_dlt_pipeline

from .resources import DEFAULT_ENDPOINT_SPECS, EndpointSpec
from .source import DEFAULT_OPENFACET_BASE_URL, build_openfacet_source

OPENFACET_PIPELINE_NAME = "openfacet"
OPENFACET_DATASET_NAME = "raw_openfacet"


def build_openfacet_pipeline(pipeline_name: str = OPENFACET_PIPELINE_NAME):
    """Build a dlt pipeline instance for OpenFacet."""
    return build_dlt_pipeline(
        connector_name=pipeline_name,
        dataset_name=OPENFACET_DATASET_NAME,
    )


__all__ = [
    "DEFAULT_ENDPOINT_SPECS",
    "DEFAULT_OPENFACET_BASE_URL",
    "EndpointSpec",
    "OPENFACET_DATASET_NAME",
    "OPENFACET_PIPELINE_NAME",
    "build_openfacet_pipeline",
    "build_openfacet_source",
]
