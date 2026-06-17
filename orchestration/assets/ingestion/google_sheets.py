from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.google_sheets import (
    build_google_sheets_pipeline,
    build_google_sheets_source,
)

from .translator import IngestionDagsterDltTranslator


class GoogleSheetsIngestionConfig(Config):
    """Runtime config exposed in Dagster for Google Sheets loads."""

    full_refresh: bool = False


def _selected_google_sheets_resources(context: AssetExecutionContext) -> list[str]:
    """Helper to extract selected Google Sheets resource names from context."""
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3
            and key.path[0] == "ingestion"
            and key.path[1] == "google_sheets"
        }
    )


@dlt_assets(
    dlt_source=build_google_sheets_source(),
    dlt_pipeline=build_google_sheets_pipeline(),
    name="google_sheets_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def google_sheets_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: GoogleSheetsIngestionConfig,
):
    """Run Google Sheets ingestion through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_google_sheets_resources(context)

    if not selected_resources:
        context.log.warning("No selected Google Sheets resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_google_sheets_source(),
            dlt_pipeline=build_google_sheets_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"google_sheets_{resource_name}"
        context.log.info(
            f"Running Google Sheets resource={resource_name} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_google_sheets_source().with_resources(resource_name),
            dlt_pipeline=build_google_sheets_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["GoogleSheetsIngestionConfig", "google_sheets_assets"]
