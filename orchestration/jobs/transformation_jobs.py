from dagster import AssetSelection

from .common import build_asset_selection, define_tagged_asset_job


def _marketing_selection(*model_names: str) -> AssetSelection:
    return build_asset_selection(
        *[
            ("transformation", "analytics", "marketing", model_name)
            for model_name in model_names
        ]
    )


transformation__marketing__marts__job = (
    define_tagged_asset_job(
        name="transformation__marketing__marts__job",
        selection=_marketing_selection(
            "fct_fb_ads_performance_daily",
            "fct_marketing_performance_daily",
        ),
        description="Refresh selected marketing dbt marts",
        layer="transformation",
        tool="dbt",
        system="marketing",
        family="marts",
        cadence="twice_daily",
    )
)

__all__ = ["transformation__marketing__marts__job"]
