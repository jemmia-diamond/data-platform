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
            description="Refresh fct_pancake_conversations mart (manual on-demand run; automated execution is triggered eagerly when raw conversations update)",
            cadence="manual",
            max_runtime_seconds=300,
        ),
    )
)


__all__ = ["PANCAKE_MARTS_EXECUTION_UNITS"]
