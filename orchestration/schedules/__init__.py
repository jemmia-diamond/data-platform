from ..catalogs import all_execution_units
from ..catalogs.ingestion import all_execution_units as ingestion_execution_units
from ..catalogs.transformation import all_execution_units as transformation_execution_units
from ..jobs import jobs_by_name
from .common import build_schedules_by_name

schedules_by_name = build_schedules_by_name(all_execution_units, jobs_by_name)
transformation_schedules = tuple(
    schedules_by_name[spec.schedule_name]
    for spec in transformation_execution_units
    if spec.has_schedule
)
ingestion_schedules = tuple(
    schedules_by_name[spec.schedule_name]
    for spec in ingestion_execution_units
    if spec.has_schedule
)
all_schedules = transformation_schedules + ingestion_schedules

__all__ = [
    "all_schedules",
    "ingestion_schedules",
    "schedules_by_name",
    "transformation_schedules",
]
