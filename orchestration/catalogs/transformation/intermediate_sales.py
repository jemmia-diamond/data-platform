from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "intermediate", "sales", model_name)
        for model_name in model_names
    )


def _asset_paths_nested(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "intermediate", "sales", "haravan", model_name)
        for model_name in model_names
    )


INTERMEDIATE_SALES_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="sales",
            unit="intermediate_tables",
            asset_paths=_asset_paths_nested(
                "int_haravan__order_ancestry",
            ) + _asset_paths(
                "int_sales__orders",
            ),
            description="Refresh intermediate sales tables (materialized from view)",
            cadence="10m",
            cron_schedule="4,14,24,34,44,54 * * * *",
            schedule_token="every_10m",
            schedule_description="Refresh intermediate sales tables every 10 minutes (offset +4m from ingestion)",
            max_runtime_seconds=480,
        ),
    )
)


__all__ = ["INTERMEDIATE_SALES_EXECUTION_UNITS"]
