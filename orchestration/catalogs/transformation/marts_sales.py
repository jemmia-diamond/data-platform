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
                "fct_sales_leads_orders",
                "fct_sales_lead_preferred_products",
                "fct_sales_notes",
                "fct_sales_appointments",
                "fct_sales_opportunities",
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
            cadence="every_15_minutes",
            cron_schedule="9-59/15 * * * *",
            schedule_token="every_15_minutes",
            schedule_description="Run sales marts every 15 minutes (offset +9m, after leads/sales_orders/lead_products/haravan ingestion; runs before finance)",
            max_runtime_seconds=900,
            exclude_asset_paths=(
                ("transformation", "intermediate", "sales", "int_sales__orders"),
                ("transformation", "intermediate", "sales", "haravan", "int_haravan__order_ancestry"),
                ("transformation", "intermediate", "catalog", "int_catalog__variants"),
                ("transformation", "intermediate", "catalog", "int_catalog__products"),
                ("transformation", "intermediate", "catalog", "int_catalog__designs"),
            ),
        ),
    )
)


__all__ = ["SALES_MARTS_EXECUTION_UNITS"]
