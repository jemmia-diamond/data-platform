from dagster import ScheduleDefinition

from ...jobs.maintenance import dbt_target_cleanup_job

dbt_target_cleanup_schedule = ScheduleDefinition(
    name="dbt_target_cleanup_every_6h",
    job=dbt_target_cleanup_job,
    cron_schedule="0 */6 * * *",
    description="Run dbt target directory cleanup every 6 hours to bound dagster_code disk growth.",
)

__all__ = ["dbt_target_cleanup_schedule"]
