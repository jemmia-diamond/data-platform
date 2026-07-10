from __future__ import annotations

from ingestion.larksuite import larksuite_resource_asset_path

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Build object-type-grouped Dagster asset paths for the given Larksuite resources."""
    return tuple(larksuite_resource_asset_path(resource_name) for resource_name in resource_names)


LARKSUITE_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="larksuite",
            unit="base",
            asset_paths=_asset_paths("ticket_tech_helpdesk"),
            description="Sync Larksuite Base (Bitable) tables (full load, merge on record_id)",
            cadence="daily",
            cron_schedule="0 18 * * *",
            schedule_token="daily_18utc",
            schedule_description="Run Larksuite Base sync daily at 01:00 ICT (18:00 UTC)",
            max_runtime_seconds=3600,
        ),
    )
)


__all__ = ["LARKSUITE_EXECUTION_UNITS"]
