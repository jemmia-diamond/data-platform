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
            cadence="hourly",
            cron_schedule="0 1-12 * * *",
            schedule_token="hourly",
            schedule_description="Run finance marts every hour",
            max_runtime_seconds=2700,
        ),
    )
)


__all__ = ["FINANCE_MARTS_EXECUTION_UNITS"]
