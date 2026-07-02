from .frappe_erpnext import all_schedules as frappe_erpnext_schedules
from .haravan import all_schedules as haravan_schedules
from .lark import all_schedules as lark_schedules
from .nocodb import all_schedules as nocodb_schedules
from .pancake import all_schedules as pancake_schedules

all_schedules = haravan_schedules + frappe_erpnext_schedules + nocodb_schedules + pancake_schedules + lark_schedules

__all__ = ["all_schedules", "frappe_erpnext_schedules", "haravan_schedules", "lark_schedules", "nocodb_schedules", "pancake_schedules"]

