from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.pancake import (
    DEFAULT_START_DATE,
    build_pancake_pipeline,
    build_pancake_source,
    get_pancake_start_date,
)

from .translator import IngestionDagsterDltTranslator


class PancakeIngestionConfig(Config):
    """Runtime config exposed in Dagster for Pancake loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False


def _selected_pancake_resources(context: AssetExecutionContext) -> list[str]:
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3 and key.path[0] == "ingestion" and key.path[1] == "pancake"
        }
    )


@dlt_assets(
    dlt_source=build_pancake_source(
        user_access_token="[PLACEHOLDER]",
    ),
    dlt_pipeline=build_pancake_pipeline(),
    name="pancake_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def pancake_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: PancakeIngestionConfig,
):
    """Run Pancake ingestion through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    # When neither full_refresh nor explicit start_date is set, auto-detect per table.
    auto_detect = not config.full_refresh and config.start_date == DEFAULT_START_DATE
    selected_resources = _selected_pancake_resources(context)

    if not selected_resources:
        context.log.warning("No selected Pancake resources; running full pipeline.")
        start = DEFAULT_START_DATE if config.full_refresh else get_pancake_start_date()
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(
                start_date=start,
                end_date=config.end_date,
            ),
            dlt_pipeline=build_pancake_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        if auto_detect:
            start = get_pancake_start_date(table=resource_name)
        elif config.full_refresh:
            start = DEFAULT_START_DATE
        else:
            start = config.start_date

        pipeline_name = f"pancake_{resource_name}"
        context.log.info(
            f"Running Pancake resource={resource_name} "
            f"start_date={start} end_date={config.end_date} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(
                start_date=start,
                end_date=config.end_date,
            ).with_resources(resource_name),
            dlt_pipeline=build_pancake_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["PancakeIngestionConfig", "pancake_assets"]
