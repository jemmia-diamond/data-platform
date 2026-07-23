from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "salesaya", model_name)
        for model_name in model_names
    )


SALESAYA_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="salesaya",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_salesaya_diamonds",
                "fct_salesaya_jewelry_query",
                "fct_salesaya_jewelry_retouch",
                "fct_salesaya_temporary_products",
                "fct_salesaya_lead_conversations",
                "fct_salesaya_pancake_from_fulfilled",
                "dim_salesaya_wedding_rings",
                "dim_salesaya_lead_qualification",
                "dim_salesaya_customers",
                "dim_salesaya_haravan_collections",
                "dim_salesaya_warehouses",
            ),
            description="Refresh all salesaya marts (catalog, inventory, CRM, pancake feeds)",
            cadence="every_15_minutes",
            cron_schedule="*/15 * * * *",
            schedule_token="every_15_minutes",
            schedule_description="Run salesaya marts every 15 minutes (matches legacy salesaya refresh cadence)",
            max_runtime_seconds=300,
        ),
    )
)


__all__ = ["SALESAYA_MARTS_EXECUTION_UNITS"]
