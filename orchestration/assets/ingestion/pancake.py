from typing import Optional

from dagster import AssetExecutionContext, Config, MonthlyPartitionsDefinition
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.pancake import (
    DEFAULT_PANCAKE_BASE_URL,
    DEFAULT_START_DATE,
    build_pancake_pipeline,
    build_pancake_source,
)

from .translator import IngestionDagsterDltTranslator, PancakeBackfillDagsterDltTranslator


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
        base_url=DEFAULT_PANCAKE_BASE_URL,
        page_access_tokens={"0": "[ENCRYPTION_KEY]"},  # resolved at runtime from env vars
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


__all__ = ["PancakeIngestionConfig", "pancake_assets", "pancake_backfill_assets"]


# end_offset=1 includes the current (in-progress) month so the most recent
# period can be backfilled — scheduled ingestion only covers updated_at >= the
# DEFAULT_START_DATE, so the rest of the current month is a real backfill gap.
BACKFILL_PARTITION = MonthlyPartitionsDefinition(start_date="2020-01-01", end_offset=1)

_BACKFILL_RESOURCES = ("conversations", "messages", "page_customers")


def _selected_backfill_resources(context: AssetExecutionContext) -> list[str]:
    return sorted(
        {
            key.path[3]
            for key in context.selected_asset_keys
            if (
                len(key.path) >= 4
                and key.path[0] == "ingestion"
                and key.path[1] == "pancake"
                and key.path[2] == "backfill"
            )
        }
    )


@dlt_assets(
    dlt_source=build_pancake_source(
        base_url=DEFAULT_PANCAKE_BASE_URL,
        page_access_tokens={"0": "[ENCRYPTION_KEY]"},  # resolved at runtime from env vars
    ).with_resources(*_BACKFILL_RESOURCES),
    dlt_pipeline=build_pancake_pipeline(),
    name="pancake_backfill_dlt_assets",
    partitions_def=BACKFILL_PARTITION,
    dagster_dlt_translator=PancakeBackfillDagsterDltTranslator(),
)
def pancake_backfill_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
):
    """Historical Pancake backfill driven by monthly partitions (``updated_at`` window).

    No ``op_config``: the window comes from the partition, so there is no
    None-default field to be hidden by Dagster's run-config scaffolder. Each
    partition gets an isolated dlt pipeline name so ``initial_value`` is
    honored and the scheduled incremental pipelines are never touched.
    """
    start_dt, end_dt = context.partition_time_window
    start = start_dt.isoformat()
    end = end_dt.isoformat()
    partition_key = context.partition_key
    selected_resources = _selected_backfill_resources(context)

    if not selected_resources:
        context.log.warning("No selected backfill resources; running all 3.")
        selected_resources = list(_BACKFILL_RESOURCES)

    # messages is a transformer that depends on conversations — always run together.
    resources_to_skip = set()
    if "conversations" in selected_resources and "messages" in selected_resources:
        resources_to_skip.add("messages")

    for resource_name in selected_resources:
        if resource_name in resources_to_skip:
            continue

        if resource_name == "conversations" and "messages" in selected_resources:
            run_resources = ["conversations", "messages"]
            base = "conversations_messages"
        else:
            run_resources = [resource_name]
            base = resource_name

        pipeline_name = f"pancake_backfill_{base}_{partition_key}"
        context.log.info(
            f"Backfill Pancake resources={run_resources} partition={partition_key} "
            f"start={start} end={end} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(
                start_date=start,
                end_date=end,
            ).with_resources(*run_resources),
            dlt_pipeline=build_pancake_pipeline(pipeline_name=pipeline_name),
            refresh=None,  # never drop_data — would wipe scheduled data
        )
