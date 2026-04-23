from dagster import ScheduleDefinition

from ..jobs import (
    ingestion__frappe__erpnext__activity_entities__job,
    ingestion__frappe__erpnext__address__job,
    ingestion__frappe__erpnext__contacts__job,
    ingestion__frappe__erpnext__crm_activity_entities__job,
    ingestion__frappe__erpnext__crm_pipeline_entities__job,
    ingestion__frappe__erpnext__customers__job,
    ingestion__frappe__erpnext__document_entities__job,
    ingestion__frappe__erpnext__leads__job,
    ingestion__frappe__erpnext__reference_entities__job,
    ingestion__frappe__erpnext__sales_orders__job,
    ingestion__frappe__erpnext__transactional_entities__job,
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

ingestion__frappe__erpnext__leads__every_10m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__leads__every_10m__schedule",
    job=ingestion__frappe__erpnext__leads__job,
    cron_schedule="1,11,21,31,41,51 * * * *",
    description="Run ERPNext leads every 10 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="leads",
        cadence="10m",
    ),
)

ingestion__frappe__erpnext__sales_orders__every_10m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__sales_orders__every_10m__schedule",
    job=ingestion__frappe__erpnext__sales_orders__job,
    cron_schedule="3,13,23,33,43,53 * * * *",
    description="Run ERPNext sales orders every 10 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="sales_orders",
        cadence="10m",
    ),
)

ingestion__frappe__erpnext__crm_pipeline_entities__every_10m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__crm_pipeline_entities__every_10m__schedule",
    job=ingestion__frappe__erpnext__crm_pipeline_entities__job,
    cron_schedule="5,15,25,35,45,55 * * * *",
    description="Run ERPNext CRM pipeline entities every 10 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="crm_pipeline_entities",
        cadence="10m",
    ),
)

ingestion__frappe__erpnext__crm_activity_entities__every_10m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__crm_activity_entities__every_10m__schedule",
    job=ingestion__frappe__erpnext__crm_activity_entities__job,
    cron_schedule="7,17,27,37,47,57 * * * *",
    description="Run ERPNext CRM activity entities every 10 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="crm_activity_entities",
        cadence="10m",
    ),
)

ingestion__frappe__erpnext__customers__every_20m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__customers__every_20m__schedule",
    job=ingestion__frappe__erpnext__customers__job,
    cron_schedule="2,22,42 * * * *",
    description="Run ERPNext customers every 20 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="customers",
        cadence="20m",
    ),
)

ingestion__frappe__erpnext__contacts__every_20m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__contacts__every_20m__schedule",
    job=ingestion__frappe__erpnext__contacts__job,
    cron_schedule="6,26,46 * * * *",
    description="Run ERPNext contacts every 20 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="contacts",
        cadence="20m",
    ),
)

ingestion__frappe__erpnext__address__every_20m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__address__every_20m__schedule",
    job=ingestion__frappe__erpnext__address__job,
    cron_schedule="10,30,50 * * * *",
    description="Run ERPNext address records every 20 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="address",
        cadence="20m",
    ),
)

ingestion__frappe__erpnext__transactional_entities__every_20m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__transactional_entities__every_20m__schedule",
    job=ingestion__frappe__erpnext__transactional_entities__job,
    cron_schedule="14,34,54 * * * *",
    description="Run ERPNext transactional entities every 20 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="transactional_entities",
        cadence="20m",
    ),
)

ingestion__frappe__erpnext__document_entities__every_20m__schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__document_entities__every_20m__schedule",
    job=ingestion__frappe__erpnext__document_entities__job,
    cron_schedule="18,38,58 * * * *",
    description="Run ERPNext document and audit entities every 20 minutes",
    tags=build_dagster_tags(
        layer="ingestion",
        tool="dlt",
        system="frappe_erpnext",
        family="document_entities",
        cadence="20m",
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
    "ingestion__frappe__erpnext__leads__every_10m__schedule",
    "ingestion__frappe__erpnext__sales_orders__every_10m__schedule",
    "ingestion__frappe__erpnext__crm_pipeline_entities__every_10m__schedule",
    "ingestion__frappe__erpnext__crm_activity_entities__every_10m__schedule",
    "ingestion__frappe__erpnext__customers__every_20m__schedule",
    "ingestion__frappe__erpnext__contacts__every_20m__schedule",
    "ingestion__frappe__erpnext__address__every_20m__schedule",
    "ingestion__frappe__erpnext__transactional_entities__every_20m__schedule",
    "ingestion__frappe__erpnext__document_entities__every_20m__schedule",
    "ingestion__frappe__erpnext__activity_entities__hourly__schedule",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc__schedule",
]
