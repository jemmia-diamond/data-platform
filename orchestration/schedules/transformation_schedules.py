from dagster import ScheduleDefinition

from ..jobs import transformation__marketing__marts__job
from ..tags import build_dagster_tags

transformation__marketing__marts__twice_daily__schedule = (
    ScheduleDefinition(
        name="transformation__marketing__marts__twice_daily__schedule",
        job=transformation__marketing__marts__job,
        cron_schedule="0 2,5 * * *",
        description="Run selected marketing marts at 09:00 and 12:00 ICT (02:00 and 05:00 UTC)",
        tags=build_dagster_tags(
            layer="transformation",
            tool="dbt",
            system="marketing",
            family="marts",
            cadence="twice_daily",
        ),
    )
)

__all__ = [
    "transformation__marketing__marts__twice_daily__schedule",
]
