from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "pancake", model_name)
        for model_name in model_names
    )


PANCAKE_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="pancake",
            unit="fct_pancake_conversations",
            asset_paths=_asset_paths("fct_pancake_conversations"),
            description="Refresh fct_pancake_conversations (incremental; replaces fn PancakeLeadSync source)",
            cadence="every_5_minutes",
            cron_schedule="*/5 * * * *",
            schedule_token="every_5_minutes",
            schedule_description="Run pancake conversations mart every 5 minutes (keeps it fresh for the lead-sync flow)",
            max_runtime_seconds=300,
        ),
    )
)


__all__ = ["PANCAKE_MARTS_EXECUTION_UNITS"]
