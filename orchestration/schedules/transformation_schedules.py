from dagster import ScheduleDefinition, define_asset_job, AssetSelection

# Job to run all dbt models
dbt_daily_job = define_asset_job(
    name="dbt_daily_refresh",
    selection=AssetSelection.groups("transformation"),
    description="Run all dbt models daily",
)

# Schedule: Run daily at 2:00 AM
dbt_daily_schedule = ScheduleDefinition(
    job=dbt_daily_job,
    cron_schedule="0 2 * * *",
    description="Daily dbt transformation at 2 AM",
)
