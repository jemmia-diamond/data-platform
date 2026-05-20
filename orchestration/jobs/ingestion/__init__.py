from .frappe_erpnext import all_jobs as frappe_erpnext_jobs
from .haravan import all_jobs as haravan_jobs
from .nocodb import all_jobs as nocodb_jobs

all_jobs = haravan_jobs + frappe_erpnext_jobs + nocodb_jobs

__all__ = ["all_jobs", "frappe_erpnext_jobs", "haravan_jobs", "nocodb_jobs"]

