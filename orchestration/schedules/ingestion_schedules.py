from dagster import AssetKey, AssetSelection, ScheduleDefinition, define_asset_job

from .common import build_schedule_tags


def _frappe_erpnext_selection(*resource_names: str) -> AssetSelection:
    return AssetSelection.keys(
        *[AssetKey(["ingestion", "frappe", "erpnext", resource_name]) for resource_name in resource_names]
    )

# Haravan

ingestion__haravan__inventory_locations__every_5m_job = define_asset_job(
    name="ingestion__haravan__inventory_locations__every_5m_job",
    selection=AssetSelection.keys(AssetKey(["ingestion", "haravan", "inventory_locations"])),
    description="Refresh Haravan inventory locations",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="haravan",
        group="inventory_locations",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="haravan",
        group="inventory_locations",
    ),
)

ingestion__haravan__inventory_locations__every_5m_schedule = ScheduleDefinition(
    name="ingestion__haravan__inventory_locations__every_5m_schedule",
    job=ingestion__haravan__inventory_locations__every_5m_job,
    cron_schedule="*/5 * * * *",
    description="Run Haravan inventory locations every 5 minutes",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="haravan",
        group="inventory_locations",
    ),
)

ingestion__haravan__core_entities__every_10m_job = define_asset_job(
    name="ingestion__haravan__core_entities__every_10m_job",
    selection=AssetSelection.keys(
        AssetKey(["ingestion", "haravan", "orders"]),
        AssetKey(["ingestion", "haravan", "products"]),
        AssetKey(["ingestion", "haravan", "customers"]),
        AssetKey(["ingestion", "haravan", "events"]),
    ),
    description="Refresh core incremental Haravan entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="10m",
        source="haravan",
        group="core_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="10m",
        source="haravan",
        group="core_entities",
    ),
)

ingestion__haravan__core_entities__every_10m_schedule = ScheduleDefinition(
    name="ingestion__haravan__core_entities__every_10m_schedule",
    job=ingestion__haravan__core_entities__every_10m_job,
    cron_schedule="*/10 * * * *",
    description="Run Haravan orders/products/customers/events every 10 minutes",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="10m",
        source="haravan",
        group="core_entities",
    ),
)

ingestion__haravan__reference_entities__daily_01utc_job = define_asset_job(
    name="ingestion__haravan__reference_entities__daily_01utc_job",
    selection=AssetSelection.keys(
        AssetKey(["ingestion", "haravan", "custom_collections"]),
        AssetKey(["ingestion", "haravan", "locations"]),
        AssetKey(["ingestion", "haravan", "smart_collections"]),
        AssetKey(["ingestion", "haravan", "users"]),
    ),
    description="Refresh lower-frequency Haravan reference entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="haravan",
        group="reference_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="haravan",
        group="reference_entities",
    ),
)

ingestion__haravan__reference_entities__daily_01utc_schedule = ScheduleDefinition(
    name="ingestion__haravan__reference_entities__daily_01utc_schedule",
    job=ingestion__haravan__reference_entities__daily_01utc_job,
    cron_schedule="0 1 * * *",
    description="Run Haravan reference entities daily at 08:00 ICT (01:00 UTC)",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="haravan",
        group="reference_entities",
    ),
)

# Frappe ERPNext

ingestion__frappe__erpnext__realtime_entities__every_5m_job = define_asset_job(
    name="ingestion__frappe__erpnext__realtime_entities__every_5m_job",
    selection=_frappe_erpnext_selection(
        "leads",
        "lead_products",
        "opportunities",
        "communications",
        "call_logs",
        "sales_orders",
    ),
    description="Refresh near-real-time ERPNext CRM and sales entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="frappe_erpnext",
        group="realtime_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="frappe_erpnext",
        group="realtime_entities",
    ),
)

ingestion__frappe__erpnext__realtime_entities__every_5m_schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__realtime_entities__every_5m_schedule",
    job=ingestion__frappe__erpnext__realtime_entities__every_5m_job,
    cron_schedule="*/5 * * * *",
    description="Run ERPNext leads/opportunities/communications/call_logs/sales_orders every 5 minutes",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="5m",
        source="frappe_erpnext",
        group="realtime_entities",
    ),
)

ingestion__frappe__erpnext__business_entities__every_15m_job = define_asset_job(
    name="ingestion__frappe__erpnext__business_entities__every_15m_job",
    selection=_frappe_erpnext_selection(
        "customers",
        "contacts",
        "address",
        "payment_entries",
        "bank_transactions",
        "buyback_exchanges",
        "comments",
        "files",
        "deleted_documents",
        "web_forms",
    ),
    description="Refresh transactional ERPNext business entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="15m",
        source="frappe_erpnext",
        group="business_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="15m",
        source="frappe_erpnext",
        group="business_entities",
    ),
)

ingestion__frappe__erpnext__business_entities__every_15m_schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__business_entities__every_15m_schedule",
    job=ingestion__frappe__erpnext__business_entities__every_15m_job,
    cron_schedule="2,17,32,47 * * * *",
    description="Run ERPNext customers/contacts/payments/files/comments every 15 minutes with slight offset",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="15m",
        source="frappe_erpnext",
        group="business_entities",
    ),
)

ingestion__frappe__erpnext__activity_entities__hourly_job = define_asset_job(
    name="ingestion__frappe__erpnext__activity_entities__hourly_job",
    selection=_frappe_erpnext_selection(
        "users",
        "view_logs",
        "access_logs",
        "user_permissions",
        "notification_settings",
        "employees",
        "sales_persons",
        "process_subscriptions",
    ),
    description="Refresh ERPNext user, activity, and operational entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="hourly",
        source="frappe_erpnext",
        group="activity_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="hourly",
        source="frappe_erpnext",
        group="activity_entities",
    ),
)

ingestion__frappe__erpnext__activity_entities__hourly_schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__activity_entities__hourly_schedule",
    job=ingestion__frappe__erpnext__activity_entities__hourly_job,
    cron_schedule="10 * * * *",
    description="Run ERPNext activity and operational entities hourly at minute 10",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="hourly",
        source="frappe_erpnext",
        group="activity_entities",
    ),
)

ingestion__frappe__erpnext__reference_entities__daily_01utc_job = define_asset_job(
    name="ingestion__frappe__erpnext__reference_entities__daily_01utc_job",
    selection=_frappe_erpnext_selection(
        "regions",
        "lead_sources",
        "sales_stages",
        "market_segments",
        "opportunity_types",
        "provinces",
        "lead_budgets",
        "lead_demands",
        "reports",
        "roles",
        "translations",
        "role_profiles",
        "bank_accounts",
        "monthly_distributions",
        "accounts",
        "todos",
        "tags",
        "product_categories",
        "serials",
        "purchase_purposes",
        "policies",
        "promotions",
        "sales_partner_types",
        "promotion_groups",
        "uom_conversion_factors",
    ),
    description="Refresh lower-frequency ERPNext reference and master data entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="frappe_erpnext",
        group="reference_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="frappe_erpnext",
        group="reference_entities",
    ),
)

ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule = ScheduleDefinition(
    name="ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule",
    job=ingestion__frappe__erpnext__reference_entities__daily_01utc_job,
    cron_schedule="0 1 * * *",
    description="Run ERPNext reference entities daily at 08:00 ICT (01:00 UTC)",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="daily",
        source="frappe_erpnext",
        group="reference_entities",
    ),
)

ingestion__frappe__erpnext__config_entities__manual_job = define_asset_job(
    name="ingestion__frappe__erpnext__config_entities__manual_job",
    selection=_frappe_erpnext_selection("property_setters"),
    description="Manual refresh for ERPNext configuration entities",
    tags=build_schedule_tags(
        layer="ingestion",
        cadence="manual",
        source="frappe_erpnext",
        group="config_entities",
    ),
    run_tags=build_schedule_tags(
        layer="ingestion",
        cadence="manual",
        source="frappe_erpnext",
        group="config_entities",
    ),
)

__all__ = [
    # Haravan
    "ingestion__haravan__inventory_locations__every_5m_job",
    "ingestion__haravan__inventory_locations__every_5m_schedule",
    "ingestion__haravan__core_entities__every_10m_job",
    "ingestion__haravan__core_entities__every_10m_schedule",
    "ingestion__haravan__reference_entities__daily_01utc_job",
    "ingestion__haravan__reference_entities__daily_01utc_schedule",
    # Frappe ERPNext
    "ingestion__frappe__erpnext__realtime_entities__every_5m_job",
    "ingestion__frappe__erpnext__realtime_entities__every_5m_schedule",
    "ingestion__frappe__erpnext__business_entities__every_15m_job",
    "ingestion__frappe__erpnext__business_entities__every_15m_schedule",
    "ingestion__frappe__erpnext__activity_entities__hourly_job",
    "ingestion__frappe__erpnext__activity_entities__hourly_schedule",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc_job",
    "ingestion__frappe__erpnext__reference_entities__daily_01utc_schedule",
    "ingestion__frappe__erpnext__config_entities__manual_job",
]
