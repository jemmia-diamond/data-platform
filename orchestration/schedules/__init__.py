"""
Schedules module - all Dagster schedule definitions
"""
from .ingestion_schedules import (
    ingestion__frappe__erpnext__activity_entities__hourly__schedule,
    ingestion__frappe__erpnext__business_entities__every_15m__schedule,
    ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule,
    ingestion__frappe__erpnext__realtime_entities__every_5m__schedule,
    ingestion__haravan__core_entities__every_10m__schedule,
    ingestion__haravan__inventory_locations__every_5m__schedule,
    ingestion__haravan__reference_entities__daily_01utc__schedule,
)
from .transformation_schedules import (
    transformation__marketing__marts__twice_daily__schedule,
)

all_schedules = [
    transformation__marketing__marts__twice_daily__schedule,
    ingestion__haravan__inventory_locations__every_5m__schedule,
    ingestion__haravan__core_entities__every_10m__schedule,
    ingestion__haravan__reference_entities__daily_01utc__schedule,
    ingestion__frappe__erpnext__realtime_entities__every_5m__schedule,
    ingestion__frappe__erpnext__business_entities__every_15m__schedule,
    ingestion__frappe__erpnext__activity_entities__hourly__schedule,
    ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule,
]

__all__ = [
    "all_schedules",
    "transformation__marketing__marts__twice_daily__schedule",
    "ingestion__haravan__inventory_locations__every_5m__schedule",
    "ingestion__haravan__core_entities__every_10m__schedule",
    "ingestion__haravan__reference_entities__daily_01utc__schedule",
    "ingestion__frappe__erpnext__realtime_entities__every_5m__schedule",
    "ingestion__frappe__erpnext__business_entities__every_15m__schedule",
    "ingestion__frappe__erpnext__activity_entities__hourly__schedule",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule",
]
