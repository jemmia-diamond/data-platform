from dagster import ScheduleDefinition

from ..jobs import (
    ingestion__frappe__erpnext__activity_entities__job,
    ingestion__frappe__erpnext__business_entities__job,
    ingestion__frappe__erpnext__reference_entities__job,
    ingestion__frappe__erpnext__realtime_entities__job,
    ingestion__haravan__core_entities__job,
    ingestion__haravan__inventory_locations__job,
    ingestion__haravan__reference_entities__job,
)
from ..tags import build_dagster_tags

# Haravan

ingestion__haravan__inventory_locations__every_5m__schedule = ScheduleDefinition(
    name="ingestion__haravan__inventory_locations__every_5m__schedule",
    job=ingestion__haravan__inventory_locations__job,
    cron_schedule="*/5 * * * *",
    description="Run Haravan inventory locations every 5 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="haravan",
        family="inventory_locations",
        cadence="5m",
    ),
)

ingestion__haravan__core_entities__every_10m__schedule = ScheduleDefinition(
    name="ingestion__haravan__core_entities__every_10m__schedule",
    job=ingestion__haravan__core_entities__job,
    cron_schedule="*/10 * * * *",
    description="Run Haravan orders/products/customers/events every 10 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="haravan",
        family="core_entities",
        cadence="10m",
    ),
)

ingestion__haravan__reference_entities__daily_01utc__schedule = ScheduleDefinition(
    name="ingestion__haravan__reference_entities__daily_01utc__schedule",
    job=ingestion__haravan__reference_entities__job,
    cron_schedule="0 1 * * *",
    description="Run Haravan reference entities daily at 08:00 ICT (01:00 UTC)",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="haravan",
        family="reference_entities",
        cadence="daily",
    ),
)

# Frappe ERPNext

ingestion__frappe__erpnext__realtime_entities__every_5m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__realtime_entities__every_5m__schedule",
    job=ingestion__frappe__erpnext__realtime_entities__job,
    cron_schedule="*/5 * * * *",
    description="Run ERPNext leads/opportunities/communications/call_logs/sales_orders every 5 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="realtime_entities",
        cadence="5m",
    ),
)

ingestion__frappe__erpnext__business_entities__every_15m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__business_entities__every_15m__schedule",
    job=ingestion__frappe__erpnext__business_entities__job,
    cron_schedule="2,17,32,47 * * * *",
    description="Run ERPNext customers/contacts/payments/files/comments every 15 minutes with slight offset",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="business_entities",
        cadence="15m",
    ),
)

ingestion__frappe__erpnext__activity_entities__hourly__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__activity_entities__hourly__schedule",
    job=ingestion__frappe__erpnext__activity_entities__job,
    cron_schedule="10 * * * *",
    description="Run ERPNext activity and operational entities hourly at minute 10",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="activity_entities",
        cadence="hourly",
    ),
)

ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule",
    job=ingestion__frappe__erpnext__reference_entities__job,
    cron_schedule="0 1 * * *",
    description="Run ERPNext reference entities daily at 08:00 ICT (01:00 UTC)",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="reference_entities",
        cadence="daily",
    ),
)

__all__ = [
    "ingestion__haravan__inventory_locations__every_5m__schedule",
    "ingestion__haravan__core_entities__every_10m__schedule",
    "ingestion__haravan__reference_entities__daily_01utc__schedule",
    "ingestion__frappe__erpnext__realtime_entities__every_5m__schedule",
    "ingestion__frappe__erpnext__business_entities__every_15m__schedule",
    "ingestion__frappe__erpnext__activity_entities__hourly__schedule",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule",
]
