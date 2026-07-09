from .frappe_erpnext import all_jobs as frappe_erpnext_jobs
from .haravan import all_jobs as haravan_jobs
from .larksuite import all_jobs as larksuite_jobs
from .nocodb import all_jobs as nocodb_jobs
from .pancake import all_jobs as pancake_jobs

all_jobs = haravan_jobs + frappe_erpnext_jobs + nocodb_jobs + pancake_jobs + larksuite_jobs

__all__ = ["all_jobs", "frappe_erpnext_jobs", "haravan_jobs", "larksuite_jobs", "nocodb_jobs", "pancake_jobs"]

