from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "ecom", model_name)
        for model_name in model_names
    )


ECOM_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="ecom",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_ecom_jewelry_products",
                "fct_ecom_jewelry_variants",
                "fct_ecom_wedding_rings",
                "fct_ecom_diamonds_catalog",
                "dim_ecom_warehouse_stock",
            ),
            description="Refresh all ecommerce marts (jewelry products/variants, wedding rings, diamonds catalog, warehouse stock)",
            cadence="every_30_minutes",
            cron_schedule="*/30 * * * *",
            schedule_token="every_30_minutes",
            schedule_description="Run ecommerce marts every 30 minutes (matches legacy ecom MVIEW refresh cadence)",
            max_runtime_seconds=1200,
        ),
    )
)


__all__ = ["ECOM_MARTS_EXECUTION_UNITS"]
