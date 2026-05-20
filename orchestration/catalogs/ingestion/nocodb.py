from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Helper to construct Dagster asset paths for NocoDB."""
    return tuple(("ingestion", "nocodb", resource_name) for resource_name in resource_names)


NOCODB_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="nocodb",
            unit="designs",
            asset_paths=_asset_paths("designs"),
            description="Sync NocoDB designs table to PostgreSQL",
            cadence="hourly",
            cron_schedule="20 * * * *",  # Scheduled at :20 past the hour to prevent scheduling collision
            schedule_token="every_1h",
            schedule_description="Run NocoDB designs sync every hour at :20",
        ),
    )
)

__all__ = ["NOCODB_EXECUTION_UNITS"]
