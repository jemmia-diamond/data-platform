from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.nocodb import (
    DEFAULT_NOCODB_BASE_URL,
    DEFAULT_START_DATE,
    build_nocodb_pipeline,
    build_nocodb_source,
)

from .translator import IngestionDagsterDltTranslator


class NocoDBIngestionConfig(Config):
    """Runtime config exposed in Dagster for NocoDB loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False


def _selected_nocodb_resources(context: AssetExecutionContext) -> list[str]:
    """Helper to extract selected NocoDB resource names from context."""
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3 and key.path[0] == "ingestion" and key.path[1] == "nocodb"
        }
    )


@dlt_assets(
    dlt_source=build_nocodb_source(
        base_url=DEFAULT_NOCODB_BASE_URL,
        api_token="[ENCRYPTION_KEY]",  # Token resolved at runtime by dlt from env vars
    ),
    dlt_pipeline=build_nocodb_pipeline(),
    name="nocodb_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def nocodb_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: NocoDBIngestionConfig,
):
    """Run NocoDB ingestion through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_nocodb_resources(context)

    if not selected_resources:
        context.log.warning("No selected NocoDB resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_nocodb_source(
                start_date=config.start_date,
                end_date=config.end_date,
            ),
            dlt_pipeline=build_nocodb_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"nocodb_{resource_name}"
        context.log.info(
            f"Running NocoDB resource={resource_name} "
            f"with start_date={config.start_date} end_date={config.end_date} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_nocodb_source(
                start_date=config.start_date,
                end_date=config.end_date,
            ).with_resources(resource_name),
            dlt_pipeline=build_nocodb_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["NocoDBIngestionConfig", "nocodb_assets"]
