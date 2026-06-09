from __future__ import annotations

from ..common import ExecutionUnitSpec, validate_execution_units


def _asset_paths(*model_names: str) -> tuple[tuple[str, ...], ...]:
    return tuple(
        ("transformation", "marts", "marketing", model_name)
        for model_name in model_names
    )


MARKETING_MARTS_EXECUTION_UNITS = validate_execution_units(
    (
        ExecutionUnitSpec(
            layer="transformation",
            tool="dbt",
            system="marketing",
            unit="marts",
            asset_paths=_asset_paths(
                "fct_marketing_facebook_ads_daily",
                "fct_marketing_omnichannel_daily",
            ),
            description="Refresh selected marketing dbt marts",
            cadence="twice_daily",
            cron_schedule="0 2,5 * * *",
            schedule_token="twice_daily",
            schedule_description="Run selected marketing marts at 09:00 and 12:00 ICT (02:00 and 05:00 UTC)",
            max_runtime_seconds=2700,
        ),
    )
)


__all__ = ["MARKETING_MARTS_EXECUTION_UNITS"]
