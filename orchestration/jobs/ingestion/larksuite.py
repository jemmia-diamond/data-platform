from ...catalogs.ingestion.larksuite import LARKSUITE_EXECUTION_UNITS
from ..common import build_jobs_by_name

jobs_by_name = build_jobs_by_name(LARKSUITE_EXECUTION_UNITS)
all_jobs = tuple(jobs_by_name.values())

__all__ = ["all_jobs", "jobs_by_name"]
