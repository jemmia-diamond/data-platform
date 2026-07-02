from __future__ import annotations

from ingestion.lark import lark_resource_asset_path

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Build object-type-grouped Dagster asset paths for the given Lark resources."""
    return tuple(lark_resource_asset_path(resource_name) for resource_name in resource_names)


LARK_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="lark",
            unit="base",
            asset_paths=_asset_paths("crm_customers"),
            description="Sync Lark Base (Bitable) tables (full load, merge on record_id)",
            cadence="daily",
            cron_schedule="0 18 * * *",
            schedule_token="daily_18utc",
            schedule_description="Run Lark Base sync daily at 01:00 ICT (18:00 UTC)",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="lark",
            unit="sheets",
            asset_paths=_asset_paths("dump_1", "dump_2"),
            description="Sync Lark Sheets spreadsheets (full load, merge per row)",
            cadence="daily",
            cron_schedule="0 18 * * *",
            schedule_token="daily_18utc",
            schedule_description="Run Lark Sheets sync daily at 01:00 ICT (18:00 UTC)",
            max_runtime_seconds=3600,
        ),
    )
)


__all__ = ["LARK_EXECUTION_UNITS"]
