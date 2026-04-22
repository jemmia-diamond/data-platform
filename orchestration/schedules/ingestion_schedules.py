from dagster import AssetKey, AssetSelection, ScheduleDefinition, define_asset_job

ingestion__haravan__inventory_locations__every_5m_job = define_asset_job(
    name="ingestion__haravan__inventory_locations__every_5m_job",
    selection=AssetSelection.keys(AssetKey(["ingestion", "haravan", "inventory_locations"])),
    description="Refresh Haravan inventory locations",
)

ingestion__haravan__inventory_locations__every_5m_schedule = ScheduleDefinition(
    name="ingestion__haravan__inventory_locations__every_5m_schedule",
    job=ingestion__haravan__inventory_locations__every_5m_job,
    cron_schedule="*/5 * * * *",
    description="Run Haravan inventory locations every 5 minutes",
)

ingestion__haravan__core_entities__every_10m_job = define_asset_job(
    name="ingestion__haravan__core_entities__every_10m_job",
    selection=AssetSelection.keys(
        AssetKey(["ingestion", "haravan", "orders"]),
        AssetKey(["ingestion", "haravan", "products"]),
        AssetKey(["ingestion", "haravan", "customers"]),
        AssetKey(["ingestion", "haravan", "events"]),
    ),
    description="Refresh core incremental Haravan entities",
)

ingestion__haravan__core_entities__every_10m_schedule = ScheduleDefinition(
    name="ingestion__haravan__core_entities__every_10m_schedule",
    job=ingestion__haravan__core_entities__every_10m_job,
    cron_schedule="*/10 * * * *",
    description="Run Haravan orders/products/customers/events every 10 minutes",
)

ingestion__haravan__reference_entities__daily_01utc_job = define_asset_job(
    name="ingestion__haravan__reference_entities__daily_01utc_job",
    selection=AssetSelection.keys(
        AssetKey(["ingestion", "haravan", "custom_collections"]),
        AssetKey(["ingestion", "haravan", "locations"]),
        AssetKey(["ingestion", "haravan", "smart_collections"]),
        AssetKey(["ingestion", "haravan", "users"]),
    ),
    description="Refresh lower-frequency Haravan reference entities",
)

ingestion__haravan__reference_entities__daily_01utc_schedule = ScheduleDefinition(
    name="ingestion__haravan__reference_entities__daily_01utc_schedule",
    job=ingestion__haravan__reference_entities__daily_01utc_job,
    cron_schedule="0 1 * * *",
    description="Run Haravan reference entities daily at 08:00 ICT (01:00 UTC)",
)

__all__ = [
    "ingestion__haravan__inventory_locations__every_5m_job",
    "ingestion__haravan__inventory_locations__every_5m_schedule",
    "ingestion__haravan__core_entities__every_10m_job",
    "ingestion__haravan__core_entities__every_10m_schedule",
    "ingestion__haravan__reference_entities__daily_01utc_job",
    "ingestion__haravan__reference_entities__daily_01utc_schedule",
]
