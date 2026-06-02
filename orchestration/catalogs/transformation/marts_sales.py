from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "sales", model_name)
        for model_name in model_names
    )


SALES_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="sales",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_sales_orders",
                "fct_sales_order_items",
                "fct_sales_attributions",
                "dim_sales_products",
                "dim_sales_customers",
                "dim_sales_persons",
                "fct_sales_targets_monthly",
            ),
            description="Refresh sales marts",
            cadence="manual",
        ),
    )
)


__all__ = ["SALES_MARTS_EXECUTION_UNITS"]
