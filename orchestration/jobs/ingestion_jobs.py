from dagster import AssetSelection

from .common import build_asset_selection, define_tagged_asset_job


def _haravan_selection(*resource_names: str) -> AssetSelection:
    return build_asset_selection(
        *[("ingestion", "haravan", resource_name) for resource_name in resource_names]
    )


def _frappe_erpnext_selection(*resource_names: str) -> AssetSelection:
    return build_asset_selection(
        *[
            ("ingestion", "frappe", "erpnext", resource_name)
            for resource_name in resource_names
        ]
    )

# Haravan
ingestion__haravan__inventory_locations__job = define_tagged_asset_job(
    name="ingestion__haravan__inventory_locations__job",
    selection=_haravan_selection("inventory_locations"),
    description="Refresh Haravan inventory locations",
    layer="ingestion",
    tool="dlt",
    system="haravan",
    family="inventory_locations",
    cadence="5m",
)

ingestion__haravan__core_entities__job = define_tagged_asset_job(
    name="ingestion__haravan__core_entities__job",
    selection=_haravan_selection("orders", "products", "customers", "events"),
    description="Refresh core incremental Haravan entities",
    layer="ingestion",
    tool="dlt",
    system="haravan",
    family="core_entities",
    cadence="10m",
)

ingestion__haravan__reference_entities__job = define_tagged_asset_job(
    name="ingestion__haravan__reference_entities__job",
    selection=_haravan_selection(
        "custom_collections",
        "locations",
        "smart_collections",
        "users",
    ),
    description="Refresh lower-frequency Haravan reference entities",
    layer="ingestion",
    tool="dlt",
    system="haravan",
    family="reference_entities",
    cadence="daily",
)

# Frappe ERPNext
ingestion__frappe__erpnext__leads__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__leads__job",
    selection=_frappe_erpnext_selection("leads"),
    description="Refresh ERPNext leads",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="leads",
    cadence="10m",
)

ingestion__frappe__erpnext__sales_orders__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__sales_orders__job",
    selection=_frappe_erpnext_selection("sales_orders"),
    description="Refresh ERPNext sales orders",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="sales_orders",
    cadence="10m",
)

ingestion__frappe__erpnext__crm_pipeline_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__crm_pipeline_entities__job",
    selection=_frappe_erpnext_selection(
        "lead_products",
        "opportunities",
    ),
    description="Refresh ERPNext CRM pipeline entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="crm_pipeline_entities",
    cadence="10m",
)

ingestion__frappe__erpnext__crm_activity_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__crm_activity_entities__job",
    selection=_frappe_erpnext_selection(
        "call_logs",
    ),
    description="Refresh ERPNext CRM activity entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="crm_activity_entities",
    cadence="10m",
)

ingestion__frappe__erpnext__customers__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__customers__job",
    selection=_frappe_erpnext_selection("customers"),
    description="Refresh ERPNext customers",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="customers",
    cadence="20m",
)

ingestion__frappe__erpnext__contacts__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__contacts__job",
    selection=_frappe_erpnext_selection("contacts"),
    description="Refresh ERPNext contacts",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="contacts",
    cadence="20m",
)

ingestion__frappe__erpnext__address__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__address__job",
    selection=_frappe_erpnext_selection("address"),
    description="Refresh ERPNext address records",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="address",
    cadence="20m",
)

ingestion__frappe__erpnext__transactional_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__transactional_entities__job",
    selection=_frappe_erpnext_selection(
        "payment_entries",
        "bank_transactions",
        "buyback_exchanges",
    ),
    description="Refresh ERPNext transactional entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="transactional_entities",
    cadence="20m",
)

ingestion__frappe__erpnext__document_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__document_entities__job",
    selection=_frappe_erpnext_selection(
        "comments",
        "files",
        "deleted_documents",
        "web_forms",
    ),
    description="Refresh ERPNext document and audit entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="document_entities",
    cadence="20m",
)

ingestion__frappe__erpnext__activity_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__activity_entities__job",
    selection=_frappe_erpnext_selection(
        "users",
        "view_logs",
        "access_logs",
        "user_permissions",
        "notification_settings",
        "sales_persons",
        "process_subscriptions",
    ),
    description="Refresh ERPNext user, activity, and operational entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="activity_entities",
    cadence="hourly",
)

ingestion__frappe__erpnext__reference_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__reference_entities__job",
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
        "employees"
    ),
    description="Refresh lower-frequency ERPNext reference and master data entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="reference_entities",
    cadence="daily",
)

ingestion__frappe__erpnext__config_entities__job = define_tagged_asset_job(
    name="ingestion__frappe__erpnext__config_entities__job",
    selection=_frappe_erpnext_selection("property_setters"),
    description="Manual refresh for ERPNext configuration entities",
    layer="ingestion",
    tool="dlt",
    system="frappe_erpnext",
    family="config_entities",
    cadence="manual",
)

__all__ = [
    "ingestion__haravan__inventory_locations__job",
    "ingestion__haravan__core_entities__job",
    "ingestion__haravan__reference_entities__job",
    "ingestion__frappe__erpnext__leads__job",
    "ingestion__frappe__erpnext__sales_orders__job",
    "ingestion__frappe__erpnext__crm_pipeline_entities__job",
    "ingestion__frappe__erpnext__crm_activity_entities__job",
    "ingestion__frappe__erpnext__customers__job",
    "ingestion__frappe__erpnext__contacts__job",
    "ingestion__frappe__erpnext__address__job",
    "ingestion__frappe__erpnext__transactional_entities__job",
    "ingestion__frappe__erpnext__document_entities__job",
    "ingestion__frappe__erpnext__activity_entities__job",
    "ingestion__frappe__erpnext__reference_entities__job",
    "ingestion__frappe__erpnext__config_entities__job",
]
