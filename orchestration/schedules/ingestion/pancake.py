from ...catalogs.ingestion.pancake import PANCAKE_EXECUTION_UNITS
from ...jobs.ingestion.pancake import jobs_by_name
from ..common import build_schedules_by_name

schedules_by_name = build_schedules_by_name(PANCAKE_EXECUTION_UNITS, jobs_by_name)
all_schedules = tuple(schedules_by_name.values())

__all__ = ["all_schedules", "schedules_by_name"]
