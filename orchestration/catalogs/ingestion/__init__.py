from .frappe_erpnext import FRAPPE_ERPNEXT_EXECUTION_UNITS
from .haravan import HARAVAN_EXECUTION_UNITS

all_execution_units = HARAVAN_EXECUTION_UNITS + FRAPPE_ERPNEXT_EXECUTION_UNITS

__all__ = [
    "FRAPPE_ERPNEXT_EXECUTION_UNITS",
    "HARAVAN_EXECUTION_UNITS",
    "all_execution_units",
]
