from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "intermediate", "catalog", model_name)
        for model_name in model_names
    )


INTERMEDIATE_CATALOG_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="catalog",
            unit="intermediate_tables",
            asset_paths=_asset_paths(
                "int_catalog__variants",
                "int_catalog__products",
                "int_catalog__designs",
            ),
            description="Refresh shared intermediate catalog tables (materialized as table)",
            cadence="every_2_hours",
            cron_schedule="15 */2 * * *",
            schedule_token="every_2_hours",
            schedule_description="Refresh intermediate catalog tables every 2 hours at XX:15 (offset from ecom/salesaya runs)",
            max_runtime_seconds=600,
        ),
    )
)


__all__ = ["INTERMEDIATE_CATALOG_EXECUTION_UNITS"]
