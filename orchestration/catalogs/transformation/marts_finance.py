from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "finance", model_name)
        for model_name in model_names
    )


FINANCE_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="finance",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_finance_balance_sheet_monthly",
                "fct_finance_buyback_exchange",
                "fct_finance_cashflow_monthly",
                "fct_finance_income_statement_monthly",
                "fct_finance_inventory_balance_daily",
                "fct_finance_journal_entries_monthly",
                "fct_finance_risk_supplier_monthly",
                "fct_finance_sales_payment",
                "fct_finance_sales_payment_aggregation",
                "fct_finance_sales_payment_reconciliation",
                "fct_finance_sales_pending_order",
            ),
            description="Refresh all finance marts",
            cadence="every_2_hours",
            cron_schedule="13 */2 * * *",
            schedule_token="every_2_hours",
            schedule_description="Run finance marts every 2 hours (offset +13m, after customers/payments/buyback ingestion)",
            max_runtime_seconds=2700,
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


__all__ = ["FINANCE_MARTS_EXECUTION_UNITS"]
