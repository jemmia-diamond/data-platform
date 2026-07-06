from dagster import AssetExecutionContext
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.openfacet import (
    build_openfacet_pipeline,
    build_openfacet_source,
)

from .translator import IngestionDagsterDltTranslator


def _selected_openfacet_resources(context: AssetExecutionContext) -> list[str]:
    """Helper to extract selected OpenFacet resource names from context."""
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3
            and key.path[0] == "ingestion"
            and key.path[1] == "openfacet"
        }
    )


@dlt_assets(
    dlt_source=build_openfacet_source(),
    dlt_pipeline=build_openfacet_pipeline(),
    name="openfacet_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def openfacet_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
):
    """Run OpenFacet daily snapshot ingestion.

    Data is a daily benchmark snapshot merged on ``snapshot_date`` (one row per
    published day per endpoint). There is intentionally no full-refresh option:
    re-running the same day updates the existing day's row in place and never
    duplicates. The 2x/day schedule only exists for resilience.
    """
    selected_resources = _selected_openfacet_resources(context)

    if not selected_resources:
        context.log.warning("No selected OpenFacet resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_openfacet_source(),
            dlt_pipeline=build_openfacet_pipeline(),
            refresh=None,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"openfacet_{resource_name}"
        context.log.info(
            f"Running OpenFacet resource={resource_name} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_openfacet_source().with_resources(resource_name),
            dlt_pipeline=build_openfacet_pipeline(pipeline_name=pipeline_name),
            refresh=None,
        )


__all__ = ["openfacet_assets"]
