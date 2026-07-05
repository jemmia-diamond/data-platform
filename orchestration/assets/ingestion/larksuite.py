from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.larksuite import (
    DEFAULT_LARKSUITE_BASE_URL,
    build_larksuite_pipeline,
    build_larksuite_source,
)

from .translator import LarksuiteDagsterDltTranslator


class LarksuiteIngestionConfig(Config):
    """Runtime config exposed in Dagster for Larksuite loads."""

    full_refresh: bool = False


def _selected_larksuite_resources(context: AssetExecutionContext) -> list[str]:
    """Helper to extract selected Larksuite resource names from context."""
    return sorted(
        {
            key.path[3]
            for key in context.selected_asset_keys
            if len(key.path) >= 4 and key.path[0] == "ingestion" and key.path[1] == "larksuite"
        }
    )


@dlt_assets(
    # Placeholders keep asset discovery offline: real credentials are resolved by
    # dlt from env vars at run time, and access_token short-circuits the
    # tenant-token exchange and per-Wiki resolution during this discovery build.
    dlt_source=build_larksuite_source(
        base_url=DEFAULT_LARKSUITE_BASE_URL,
        app_id="[ENCRYPTION_KEY]",
        app_secret="[ENCRYPTION_KEY]",
        access_token="[ENCRYPTION_KEY]",
    ),
    dlt_pipeline=build_larksuite_pipeline(),
    name="larksuite_dlt_assets",
    dagster_dlt_translator=LarksuiteDagsterDltTranslator(),
)
def larksuite_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: LarksuiteIngestionConfig,
):
    """Run Larksuite ingestion (Base, Sheets, Document) through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_larksuite_resources(context)

    if not selected_resources:
        context.log.warning("No selected Larksuite resources; running full pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_larksuite_source(),
            dlt_pipeline=build_larksuite_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"larksuite_{resource_name}"
        context.log.info(
            f"Running Larksuite resource={resource_name} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_larksuite_source().with_resources(resource_name),
            dlt_pipeline=build_larksuite_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["LarksuiteIngestionConfig", "larksuite_assets"]
