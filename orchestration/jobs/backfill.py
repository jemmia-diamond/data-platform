from dagster import AssetKey, AssetSelection, define_asset_job

pancake_backfill_job = define_asset_job(
    name="ingestion__pancake__backfill__job",
    selection=AssetSelection.keys(
        AssetKey(["ingestion", "pancake", "backfill", "conversations"]),
        AssetKey(["ingestion", "pancake", "backfill", "messages"]),
        AssetKey(["ingestion", "pancake", "backfill", "page_customers"]),
    ),
    description=(
        "Manual Pancake historical backfill (monthly partitions, updated_at window). "
        "No schedule. Launch from the asset graph backfill modal and pick a month range, "
        "or from Launchpad with a single partition. conversations+messages must run together."
    ),
    tags={
        "layer": "ingestion",
        "tool": "dlt",
        "system": "pancake",
        "unit": "backfill",
        "cadence": "manual",
        "dagster/max_runtime": "7200",
    },
    run_tags={
        "layer": "ingestion",
        "tool": "dlt",
        "system": "pancake",
        "unit": "backfill",
        "cadence": "manual",
        "dagster/max_runtime": "7200",
    },
)


__all__ = ["pancake_backfill_job"]
