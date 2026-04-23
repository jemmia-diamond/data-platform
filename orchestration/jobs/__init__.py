from .ingestion_jobs import (
    ingestion__frappe__erpnext__activity_entities__job,
    ingestion__frappe__erpnext__business_entities__job,
    ingestion__frappe__erpnext__config_entities__job,
    ingestion__frappe__erpnext__reference_entities__job,
    ingestion__frappe__erpnext__realtime_entities__job,
    ingestion__haravan__core_entities__job,
    ingestion__haravan__inventory_locations__job,
    ingestion__haravan__reference_entities__job,
)
from .transformation_jobs import (
    transformation__marketing__marts__job,
)

all_jobs = [
    transformation__marketing__marts__job,
    ingestion__haravan__inventory_locations__job,
    ingestion__haravan__core_entities__job,
    ingestion__haravan__reference_entities__job,
    ingestion__frappe__erpnext__realtime_entities__job,
    ingestion__frappe__erpnext__business_entities__job,
    ingestion__frappe__erpnext__activity_entities__job,
    ingestion__frappe__erpnext__reference_entities__job,
    ingestion__frappe__erpnext__config_entities__job,
]

__all__ = [
    "all_jobs",
    "transformation__marketing__marts__job",
    "ingestion__haravan__inventory_locations__job",
    "ingestion__haravan__core_entities__job",
    "ingestion__haravan__reference_entities__job",
    "ingestion__frappe__erpnext__realtime_entities__job",
    "ingestion__frappe__erpnext__business_entities__job",
    "ingestion__frappe__erpnext__activity_entities__job",
    "ingestion__frappe__erpnext__reference_entities__job",
    "ingestion__frappe__erpnext__config_entities__job",
]
