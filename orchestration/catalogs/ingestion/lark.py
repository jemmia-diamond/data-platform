from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Helper to construct Dagster asset paths for Lark."""
    return tuple(("ingestion", "lark", resource_name) for resource_name in resource_names)


LARK_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="lark",
            unit="bitable",
            asset_paths=_asset_paths("crm_customers"),
            description="Sync Lark Bitable tables (full load, merge on record_id)",
            cadence="daily",
            cron_schedule="0 9 * * *",
            schedule_token="daily_18utc",
            schedule_description="Run Lark Bitable sync daily at 01:00 ICT (18:00 UTC)",
            max_runtime_seconds=3600,
        ),
    )
)


__all__ = ["LARK_EXECUTION_UNITS"]
