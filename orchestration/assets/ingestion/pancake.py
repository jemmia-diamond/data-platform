"""Dagster assets for Pancake ingestion."""

from typing import Optional

from dagster import AssetExecutionContext, AssetKey, Config, asset
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.pancake import (
    DEFAULT_PANCAKE_BASE_URL,
    DEFAULT_START_DATE,
    build_pancake_pipeline,
    build_pancake_source,
    load_page_access_tokens,
)
from ingestion.pancake.messages_queue import (
    build_messages_pipeline,
    drain_message_jobs,
    enqueue_message_jobs,
)

from .translator import IngestionDagsterDltTranslator

# The @dlt_assets decorator instantiates the source once at import time, purely
# to derive asset keys — the translator reads only resource names, nothing is
# fetched. Tokens resolve lazily inside pancake_source at runtime, so a non-None
# placeholder keeps code-location load off the network (Infisical).
_PLACEHOLDER_TOKENS = {"_": "resolved-at-runtime"}


class PancakeIngestionConfig(Config):
    """Runtime config exposed in Dagster for Pancake loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False


def _selected_pancake_resources(context: AssetExecutionContext) -> list[str]:
    """Resource names selected for this run (from Dagster's asset selection)."""
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
        page_access_tokens=_PLACEHOLDER_TOKENS,
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
    """Run selected Pancake dlt resources (conversations + table resources)."""
    refresh = "drop_data" if config.full_refresh else None
    start = DEFAULT_START_DATE if config.full_refresh else config.start_date
    selected = _selected_pancake_resources(context)

    if not selected:
        context.log.warning("No Pancake resources selected; running the full pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(start_date=start, end_date=config.end_date),
            dlt_pipeline=build_pancake_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected:
        context.log.info(
            f"Pancake resource={resource_name} start_date={start} "
            f"end_date={config.end_date} full_refresh={config.full_refresh}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_pancake_source(
                start_date=start, end_date=config.end_date
            ).with_resources(resource_name),
            dlt_pipeline=build_pancake_pipeline(pipeline_name=f"pancake_{resource_name}"),
            refresh=refresh,
        )


@asset(
    key=AssetKey(["ingestion", "pancake", "message_jobs_enqueue"]),
    group_name="ingestion",
    required_resource_keys={"pancake_queue"},
    description=(
        "Upsert pending message jobs from raw_pancake.conversations "
        "(message_count > 0). No Dagster dependency on the conversations asset: "
        "lineage is table-based — conversations loads hourly, enqueue reads the table."
    ),
)
def message_jobs_enqueue(context: AssetExecutionContext) -> dict:
    """Top up the message queue from newly discovered conversations."""
    with context.resources.pancake_queue.get_connection() as conn:
        result = enqueue_message_jobs(conn)
    note = f" ({result['note']})" if result["note"] else ""
    context.log.info(
        f"Message jobs enqueue: enqueued={result['enqueued']} "
        f"pending={result['pending']} total={result['total']}{note}"
    )
    return result


@asset(
    key=AssetKey(["ingestion", "pancake", "message_jobs_drain"]),
    deps=[AssetKey(["ingestion", "pancake", "message_jobs_enqueue"])],
    group_name="ingestion",
    required_resource_keys={"pancake_queue"},
    description=(
        "Drain the pancake_sync.message_jobs queue: claim (SKIP LOCKED), fetch "
        "messages concurrently via a worker pool, batch-load via dlt, and "
        "checkpoint current_count per chunk for crash-safe resume."
    ),
)
def message_jobs_drain(context: AssetExecutionContext) -> dict:
    """Claim and process message jobs until the drain budget elapses."""
    tokens = load_page_access_tokens()
    pipeline = build_messages_pipeline()
    with context.resources.pancake_queue.get_connection() as conn:
        result = drain_message_jobs(
            context.log, conn, pipeline, tokens, DEFAULT_PANCAKE_BASE_URL
        )
    context.log.info(
        f"Message jobs drain: claimed={result['claimed']} done={result['done']} "
        f"retried={result['retried']} dead={result['dead']} "
        f"rows_loaded={result['rows_loaded']} batches={result['batches']} "
        f"pages_blocked={result.get('pages_blocked', 0)} "
        f"pending_remaining={result['pending_remaining']}"
    )
    return result


__all__ = [
    "PancakeIngestionConfig",
    "message_jobs_drain",
    "message_jobs_enqueue",
    "pancake_assets",
]
