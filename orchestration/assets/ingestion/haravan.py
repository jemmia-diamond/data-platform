from typing import Optional

from dagster import AssetExecutionContext, AssetKey, Config, asset
from dagster_dlt import DagsterDltResource, dlt_assets

from ingestion.haravan import (
    DEFAULT_HARAVAN_BASE_URL,
    DEFAULT_START_DATE,
    build_haravan_pipeline,
    build_haravan_source,
)
from ingestion.haravan.snapshot import snapshot_table

from .translator import IngestionDagsterDltTranslator


class HaravanIngestionConfig(Config):
    """Runtime config exposed in Dagster for Haravan loads."""

    start_date: str = DEFAULT_START_DATE
    end_date: Optional[str] = None
    full_refresh: bool = False


def _selected_haravan_resources(context: AssetExecutionContext) -> list[str]:
    return sorted(
        {
            key.path[2]
            for key in context.selected_asset_keys
            if len(key.path) >= 3 and key.path[0] == "ingestion" and key.path[1] == "haravan"
        }
    )


@dlt_assets(
    dlt_source=build_haravan_source(
        base_url=DEFAULT_HARAVAN_BASE_URL,
        api_token="[ENCRYPTION_KEY]", # override by config
    ),
    dlt_pipeline=build_haravan_pipeline(),
    name="haravan_dlt_assets",
    dagster_dlt_translator=IngestionDagsterDltTranslator(),
)
def haravan_assets(
    context: AssetExecutionContext,
    dlt: DagsterDltResource,
    config: HaravanIngestionConfig,
):
    """Run Haravan ingestion through dagster-dlt."""
    refresh = "drop_data" if config.full_refresh else None
    selected_resources = _selected_haravan_resources(context)

    if not selected_resources:
        context.log.warning("No selected Haravan resources; run with default pipeline.")
        yield from dlt.run(
            context=context,
            dlt_source=build_haravan_source(
                start_date=config.start_date,
                end_date=config.end_date,
            ),
            dlt_pipeline=build_haravan_pipeline(),
            refresh=refresh,
        )
        return

    for resource_name in selected_resources:
        pipeline_name = f"haravan_{resource_name}"
        context.log.info(
            f"Running Haravan resource={resource_name} "
            f"with start_date={config.start_date} end_date={config.end_date} "
            f"full_refresh={config.full_refresh} pipeline_name={pipeline_name}"
        )
        yield from dlt.run(
            context=context,
            dlt_source=build_haravan_source(
                start_date=config.start_date,
                end_date=config.end_date,
            ).with_resources(resource_name),
            dlt_pipeline=build_haravan_pipeline(pipeline_name=pipeline_name),
            refresh=refresh,
        )


@asset(
    key=AssetKey(["ingestion", "haravan", "inventory_locations_snapshot"]),
    deps=[AssetKey(["ingestion", "haravan", "inventory_locations"])],
    group_name="ingestion",
    required_resource_keys={"haravan_snapshot"},
    description=(
        "Daily end-of-day snapshot of raw_haravan.inventory_locations into "
        "inventory_locations_snapshot (adds snapshot_date). The source table is "
        "a merge-on-latest dlt resource with no history, so this asset copies it "
        "once a day to preserve inventory history."
    ),
)
def inventory_locations_snapshot(context: AssetExecutionContext) -> dict:
    """Snapshot raw_haravan.inventory_locations, stamped with today's date.

    To add a snapshot for another Haravan table, add a sibling @asset that
    calls `snapshot_table(conn, source_table=..., key_columns=...)` — the
    table DDL, upsert SQL, and resource connection are all reused as-is.
    """
    with context.resources.haravan_snapshot.get_connection() as conn:
        result = snapshot_table(
            conn,
            source_table="inventory_locations",
            key_columns=("loc_id", "variant_id"),
        )
    context.log.info(
        f"Inventory snapshot: rows={result['rows']} snapshot_date={result['snapshot_date']}"
    )
    return result


__all__ = ["HaravanIngestionConfig", "haravan_assets", "inventory_locations_snapshot"]
