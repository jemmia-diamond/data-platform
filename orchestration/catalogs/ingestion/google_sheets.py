from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Helper to construct Dagster asset paths for Google Sheets."""
    return tuple(
        ("ingestion", "google_sheets", resource_name) for resource_name in resource_names
    )


GOOGLE_SHEETS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="google_sheets",
            unit="recruitment",
            name_segments=("google_sheets",),
            asset_paths=_asset_paths("recruitment"),
            description="Sync Google Sheets: Recruitment (candidates)",
            cadence="daily",
            cron_schedule="15 6 * * *",
            schedule_token="every_1d",
            schedule_description="Run daily at 06:15",
            max_runtime_seconds=3600,
        ),
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="google_sheets",
            unit="employee_status",
            name_segments=("google_sheets",),
            asset_paths=_asset_paths("employee_status"),
            description="Sync Google Sheets: Employee Status",
            cadence="daily",
            cron_schedule="15 6 * * *",
            schedule_token="every_1d",
            schedule_description="Run daily at 06:15",
            max_runtime_seconds=3600,
        ),
    )
)

__all__ = ["GOOGLE_SHEETS_EXECUTION_UNITS"]
