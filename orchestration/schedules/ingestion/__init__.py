from .frappe_erpnext import all_schedules as frappe_erpnext_schedules
from .haravan import all_schedules as haravan_schedules
from .nocodb import all_schedules as nocodb_schedules

all_schedules = haravan_schedules + frappe_erpnext_schedules + nocodb_schedules

__all__ = ["all_schedules", "frappe_erpnext_schedules", "haravan_schedules", "nocodb_schedules"]

