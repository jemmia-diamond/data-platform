from ..catalogs import all_execution_units
from ..catalogs.ingestion import all_execution_units as ingestion_execution_units
from ..catalogs.transformation import all_execution_units as transformation_execution_units
from .common import build_jobs_by_name

jobs_by_name = build_jobs_by_name(all_execution_units)
transformation_jobs = tuple(jobs_by_name[spec.job_name] for spec in transformation_execution_units)
ingestion_jobs = tuple(jobs_by_name[spec.job_name] for spec in ingestion_execution_units)
all_jobs = transformation_jobs + ingestion_jobs

__all__ = ["all_jobs", "ingestion_jobs", "jobs_by_name", "transformation_jobs"]
