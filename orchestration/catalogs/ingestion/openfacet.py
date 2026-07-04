from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*resource_names: str) -> tuple[tuple[str, ...], ...]:
    """Helper to construct Dagster asset paths for OpenFacet."""
    return tuple(("ingestion", "openfacet", resource_name) for resource_name in resource_names)


OPENFACET_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="ingestion",
            tool="dlt",
            system="openfacet",
            unit="market_snapshots",
            name_segments=("openfacet",),
            asset_paths=_asset_paths(
                "dcx_index",
                "price_matrix",
                "ratio_models",
                "market_depth",
            ),
            description=(
                "Daily OpenFacet diamond market snapshots: DCX index, "
                "round price matrix, fancy-shape ratio models, market depth"
            ),
            cadence="daily",
            cron_schedule="0 7,19 * * *",
            schedule_token="twice_daily",
            schedule_description=(
                "OpenFacet snapshot sync twice daily (07:00, 19:00) for "
                "resilience; merge on snapshot_date keeps one row/day"
            ),
            max_runtime_seconds=300,
        ),
    )
)

__all__ = ["OPENFACET_EXECUTION_UNITS"]
