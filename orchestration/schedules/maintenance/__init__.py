from .dbt_target_cleanup import dbt_target_cleanup_schedule

all_schedules = (dbt_target_cleanup_schedule,)

__all__ = ["all_schedules", "dbt_target_cleanup_schedule"]
