from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(("ingestion", "misa", resource_name) for resource_name in resource_names)


MISA_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="misa",
            unit="dictionary_daily",
            asset_paths=_asset_paths(
                "inventory_items",
                "account_objects",
                "organization_units",
                "banks",
                "warehouse_inventories",
            ),
            description="Pull MISA master data + inventory balance via ACT Open API (users read from shared DB)",
            cadence="daily",
            cron_schedule="0 1 * * *",
            schedule_token="daily_01utc",
            schedule_description="Run MISA dictionary pull daily at 08:00 ICT (01:00 UTC)",
            max_runtime_seconds=3600,
        ),
    )
)


__all__ = ["MISA_EXECUTION_UNITS"]
