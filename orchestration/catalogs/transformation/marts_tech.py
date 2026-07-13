from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "tech", model_name)
        for model_name in model_names
    )


TECH_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="tech",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_tech_system_uptime_reports",
                "fct_tech_ticket_tickets",
            ),
            description="Refresh all tech marts",
            cadence="hourly",
            cron_schedule="0 1-12 * * *",
            schedule_token="hourly",
            schedule_description="Run tech marts every hour",
            max_runtime_seconds=900,
        ),
    )
)


__all__ = ["TECH_MARTS_EXECUTION_UNITS"]
