from typing import Optional

from dagster import AssetExecutionContext, Config
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.pancake import (
    DEFAULT_START_DATE,
    build_pancake_pipeline,
    build_pancake_source,
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
        page_access_tokens={"0": "[ENCRYPTION_KEY]"},
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
    refresh = "drop_data" if config.full_refresh else None
    start = DEFAULT_START_DATE if config.full_refresh else config.start_date
    selected_resources = _selected_pancake_resources(context)

    if not selected_resources:
        context.log.warning("No selected Pancake resources; running full pipeline.")
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

    # messages is a transformer that depends on conversations — always run together.
    resources_to_skip = set()
    if "conversations" in selected_resources and "messages" in selected_resources:
        resources_to_skip.add("messages")

    for resource_name in selected_resources:
        if resource_name in resources_to_skip:
            continue

        if resource_name == "conversations" and "messages" in selected_resources:
            run_resources = ["conversations", "messages"]
            pipeline_name = "pancake_conversations_messages"
        else:
            run_resources = [resource_name]
            pipeline_name = f"pancake_{resource_name}"

        context.log.info(
            f"Running Pancake resources={run_resources} "
            f"start_date={start} end_date={config.end_date} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(
                start_date=start,
                end_date=config.end_date,
            ).with_resources(*run_resources),
            dlt_pipeline=build_pancake_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


__all__ = ["PancakeIngestionConfig", "pancake_assets"]
