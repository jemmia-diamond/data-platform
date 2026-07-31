from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.misa import (
    DEFAULT_MISA_BASE_URL,
    build_misa_pipeline,
    build_misa_source,
)

from .translator import IngestionDagsterDltTranslator


class MisaIngestionConfig(Config):
    """Runtime config exposed in Dagster for MISA loads."""

    full_refresh: bool = False


def _selected_misa_resources(context: AssetExecutionContext) -> list[str]:
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3 and key.path[0] == "ingestion" and key.path[1] == "misa"
        }
    )


@dlt_assets(
    dlt_source=build_misa_source(
        base_url=DEFAULT_MISA_BASE_URL,
        app_id="[ENCRYPTION_KEY]",
        access_code="[ENCRYPTION_KEY]",
        org_company_code="[ENCRYPTION_KEY]",
    ),
    dlt_pipeline=build_misa_pipeline(),
    name="misa_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def misa_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: MisaIngestionConfig,
):
    """Run MISA ingestion through dagster-dlt.

    Credentials resolve from ``SOURCES__MISA__*`` at runtime; the incremental
    cursor for each dictionary lives in dlt resource state.
    """
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_misa_resources(context)

    if not selected_resources:
        context.log.warning("No selected MISA resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_misa_source(),
            dlt_pipeline=build_misa_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"misa_{resource_name}"
        context.log.info(
            f"Running MISA resource={resource_name} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_misa_source().with_resources(resource_name),
            dlt_pipeline=build_misa_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["MisaIngestionConfig", "misa_assets"]
