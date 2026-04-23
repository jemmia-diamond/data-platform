from dagster import AssetKey, AssetSelection, ScheduleDefinition, define_asset_job

from .common import build_schedule_tags

transformation__marketing__performance_marts__twice_daily_02_05utc_job = define_asset_job(
    name="transformation__marketing__performance_marts__twice_daily_02_05utc_job",
    selection=AssetSelection.keys(
        AssetKey(["transformation", "analytics", "marketing", "fct_fb_ads_performance_daily"]),
        AssetKey(
            ["transformation", "analytics", "marketing", "fct_marketing_performance_daily"]
        ),
    ),
    description="Refresh two marketing performance dbt models",
    tags=build_schedule_tags(
        layer="transformation",
        cadence="twice_daily",
        source="dbt",
        group="performance_marts",
    ),
    run_tags=build_schedule_tags(
        layer="transformation",
        cadence="twice_daily",
        source="dbt",
        group="performance_marts",
    ),
)

transformation__marketing__performance_marts__twice_daily_02_05utc_schedule = (
    ScheduleDefinition(
        name="transformation__marketing__performance_marts__twice_daily_02_05utc_schedule",
        job=transformation__marketing__performance_marts__twice_daily_02_05utc_job,
        cron_schedule="0 2,5 * * *",
        description="Run selected marketing analytics models at 09:00 and 12:00 ICT (02:00 and 05:00 UTC)",
        tags=build_schedule_tags(
            layer="transformation",
            cadence="twice_daily",
            source="dbt",
            group="performance_marts",
        ),
    )
)

__all__ = [
    "transformation__marketing__performance_marts__twice_daily_02_05utc_job",
    "transformation__marketing__performance_marts__twice_daily_02_05utc_schedule",
]
