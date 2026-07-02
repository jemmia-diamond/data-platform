from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.lark import (
    DEFAULT_LARK_BASE_URL,
    build_lark_pipeline,
    build_lark_source,
)

from .translator import LarkDagsterDltTranslator


class LarkIngestionConfig(Config):
    """Runtime config exposed in Dagster for Lark loads."""

    full_refresh: bool = False


def _selected_lark_resources(context: AssetExecutionContext) -> list[str]:
    """Helper to extract selected Lark resource names from context."""
    return sorted(
        {
            key.path[3]
            for key in context.selected_asset_keys
            if len(key.path) >= 4 and key.path[0] == "ingestion" and key.path[1] == "lark"
        }
    )


@dlt_assets(
    # Placeholders keep asset discovery offline: real credentials are resolved by
    # dlt from env vars at run time, and access_token short-circuits the
    # tenant-token exchange and per-Wiki resolution during this discovery build.
    dlt_source=build_lark_source(
        base_url=DEFAULT_LARK_BASE_URL,
        app_id="[ENCRYPTION_KEY]",
        app_secret="[ENCRYPTION_KEY]",
        access_token="[ENCRYPTION_KEY]",
    ),
    dlt_pipeline=build_lark_pipeline(),
    name="lark_dlt_assets",
    dagster_dlt_translator=LarkDagsterDltTranslator(),
)
def lark_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: LarkIngestionConfig,
):
    """Run Lark ingestion (Base, Sheets, Document) through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_lark_resources(context)

    if not selected_resources:
        context.log.warning("No selected Lark resources; running full pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_lark_source(),
            dlt_pipeline=build_lark_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"lark_{resource_name}"
        context.log.info(
            f"Running Lark resource={resource_name} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_lark_source().with_resources(resource_name),
            dlt_pipeline=build_lark_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["LarkIngestionConfig", "lark_assets"]
