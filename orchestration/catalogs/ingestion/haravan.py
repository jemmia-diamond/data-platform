from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(("ingestion", "haravan", resource_name) for resource_name in resource_names)


HARAVAN_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="haravan",
            unit="inventory_locations",
            asset_paths=_asset_paths("inventory_locations"),
            description="Refresh Haravan inventory locations",
            cadence="5m",
            cron_schedule="*/5 * * * *",
            schedule_token="every_5m",
            schedule_description="Run Haravan inventory locations every 5 minutes",
            max_runtime_seconds=240,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="haravan",
            unit="orders_products_customers_events_batch",
            asset_paths=_asset_paths("orders", "products", "customers", "events"),
            description="Refresh Haravan orders, products, customers, and events",
            cadence="10m",
            cron_schedule="*/10 * * * *",
            schedule_token="every_10m",
            schedule_description="Run Haravan orders, products, customers, and events every 10 minutes",
            max_runtime_seconds=480,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="haravan",
            unit="collections_locations_users_batch",
            asset_paths=_asset_paths(
                "custom_collections",
                "smart_collections",
                "locations",
                "users",
            ),
            description="Refresh Haravan custom collections, smart collections, locations, and users",
            cadence="daily",
            cron_schedule="0 1 * * *",
            schedule_token="daily_01utc",
            schedule_description="Run Haravan custom collections, smart collections, locations, and users daily at 08:00 ICT (01:00 UTC)",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="haravan",
            unit="inventory_locations_snapshot",
            asset_paths=_asset_paths("inventory_locations_snapshot"),
            description="Daily snapshot of Haravan inventory_locations into inventory_locations_snapshot (adds snapshot_date)",
            cadence="daily",
            cron_schedule="0 17 * * *",
            schedule_token="daily_17utc",
            schedule_description="Snapshot Haravan inventory_locations daily at 00:00 ICT (17:00 UTC)",
            max_runtime_seconds=180,
        ),
    )
)


__all__ = ["HARAVAN_EXECUTION_UNITS"]
