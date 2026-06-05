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
                "fct_sales_targets_monthly",
                "fct_sales_leads",
                "fct_sales_lead_preferred_products",
                "fct_sales_order_purchase_purposes",
                "fct_sales_order_product_categories",
                "fct_sales_kpi_daily",
                "dim_sales_products",
                "dim_sales_customers",
                "dim_sales_persons",
                "dim_sales_lead_sources",
                "dim_sales_dates",
                "fct_sales_order_all_metrics"
            ),
            description="Refresh all sales marts",
            cadence="hourly_business_hours",
            cron_schedule="0 1-12 * * *",
            schedule_token="hourly_business_hours",
            schedule_description="Run sales marts hourly during business hours 08:00-19:00 ICT (01:00-12:00 UTC)",
        ),
    )
)


__all__ = ["SALES_MARTS_EXECUTION_UNITS"]
