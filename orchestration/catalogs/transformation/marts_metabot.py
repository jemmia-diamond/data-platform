from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "metabot", model_name)
        for model_name in model_names
    )


METABOT_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="metabot",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_metabot_orders",
                "fct_metabot_order_items",
                "fct_metabot_commissions",
                "fct_metabot_marketing_spend",
                "fct_metabot_lead_preferred_products",
                "fct_metabot_order_purposes",
                "fct_metabot_order_product_categories",
                "fct_metabot_inventory_stock",
                "fct_metabot_inventory_serials",
                "fct_metabot_targets_monthly",
                "fct_metabot_kpi_daily",
                "dim_metabot_customers",
                "dim_metabot_leads",
                "dim_metabot_products",
                "dim_metabot_sales_persons",
                "dim_metabot_dates",
            ),
            description="Refresh all metabot marts",
            cadence="twice_daily",
            cron_schedule="0 0,12 * * *",
            schedule_token="twice_daily",
            schedule_description="Run metabot marts twice daily (midnight + noon)",
            max_runtime_seconds=2700,
        ),
    )
)


__all__ = ["METABOT_MARTS_EXECUTION_UNITS"]
