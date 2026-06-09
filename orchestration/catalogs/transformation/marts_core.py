from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "core", model_name)
        for model_name in model_names
    )


CORE_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="core",
            unit="marts",
            asset_paths=_asset_paths("dim_dates"),
            description="Core shared dimensions (static reference data)",
            cadence="manual",
            max_runtime_seconds=1800,
        ),
    )
)


__all__ = ["CORE_MARTS_EXECUTION_UNITS"]
