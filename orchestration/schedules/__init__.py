"""
Schedules module - All schedule definitions
"""
from .ingestion_schedules import (
    ingestion__frappe__erpnext__activity_entities__hourly_schedule,
    ingestion__frappe__erpnext__business_entities__every_15m_schedule,
    ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule,
    ingestion__frappe__erpnext__realtime_entities__every_5m_schedule,
    ingestion__haravan__core_entities__every_10m_schedule,
    ingestion__haravan__inventory_locations__every_5m_schedule,
    ingestion__haravan__reference_entities__daily_01utc_schedule,
)
from .transformation_schedules import (
    transformation__marketing__performance_marts__twice_daily_02_05utc_schedule,
)

all_schedules = [
    transformation__marketing__performance_marts__twice_daily_02_05utc_schedule,
    ingestion__haravan__inventory_locations__every_5m_schedule,
    ingestion__haravan__core_entities__every_10m_schedule,
    ingestion__haravan__reference_entities__daily_01utc_schedule,
    ingestion__frappe__erpnext__realtime_entities__every_5m_schedule,
    ingestion__frappe__erpnext__business_entities__every_15m_schedule,
    ingestion__frappe__erpnext__activity_entities__hourly_schedule,
    ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule,
]

__all__ = [
    "all_schedules",
    "transformation__marketing__performance_marts__twice_daily_02_05utc_schedule",
    "ingestion__haravan__inventory_locations__every_5m_schedule",
    "ingestion__haravan__core_entities__every_10m_schedule",
    "ingestion__haravan__reference_entities__daily_01utc_schedule",
    "ingestion__frappe__erpnext__realtime_entities__every_5m_schedule",
    "ingestion__frappe__erpnext__business_entities__every_15m_schedule",
    "ingestion__frappe__erpnext__activity_entities__hourly_schedule",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule",
]
