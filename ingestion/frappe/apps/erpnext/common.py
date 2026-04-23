from __future__ import annotations

"""
ERPNext resources built on top of the Frappe REST API.

This module contains "simple" resources where the pattern is:
1) Call list endpoint to get document names (paged)
2) Optionally fetch full document per name
3) Incremental sync by `modified`
"""

from datetime import datetime, timezone
from typing import Any, Optional

import dlt
from dlt.extract.resource import DltResource

from ingestion.frappe.client import FrappeClient, normalize_frappe_datetime

DEFAULT_PAGE_SIZE = 200
# Resource and Doctype
SIMPLE_DOCTYPES = (
    # === CRM Module ===
    ("leads", "Lead"),
    ("lead_products", "Lead Product"),
    ("regions", "Region"),
    ("lead_sources", "Lead Source"),
    ("sales_stages", "Sales Stage"),
    ("market_segments", "Market Segment"),
    ("opportunity_types", "Opportunity Type"),
    ("provinces", "Province"),
    ("opportunities", "Opportunity"),
    ("lead_budgets", "Lead Budget"),
    ("lead_demands", "Lead Demand"),
    ("property_setters","Property Setter"),

    # === Core Module ===
    ("deleted_documents", "Deleted Document"),
    ("users", "User"),
    ("view_logs", "View Log"),
    ("access_logs", "Access Log"),
    ("files", "File"),
    ("comments", "Comment"),
    ("reports", "Report"),
    ("roles", "Role"),
    ("translations", "Translation"),
    ("user_permissions", "User Permission"),
    ("communications", "Communication"),
    ("role_profiles", "Role Profile"),

    # === Contact ===
    ("contacts", "Contact"),
    ("address", "Address"),

    # ==== Account ===
    ("payment_entries", "Payment Entry"),
    ("bank_accounts", "Bank Account"),
    ("monthly_distributions", "Monthly Distribution"),
    ("accounts", "Account"),
    ("process_subscriptions", "Process Subscription"),
    ("bank_transactions", "Bank Transaction"),

    # ==== Desk module ===
    ("todos", "ToDo"),
    ("tags", "Tag"),
    ("notification_settings", "Notification Settings"),

    # === Selling ===
    ("product_categories", "Product Category"),
    ("serials", "Serial"),
    ("purchase_purposes", "Purchase Purpose"),
    ("policies", "Policy"),
    ("customers", "Customer"),
    ("sales_orders", "Sales Order"),
    ("promotions", "Promotion"),
    ("sales_partner_types", "Sales Partner Type"),
    ("buyback_exchanges", "Buyback Exchange"),
    ("promotion_groups", "Promotion Group"),
    ("sales_persons", "Sales Person"),
    ("uom_conversion_factors", "UOM Conversion Factor"),
    ("employees", "Employee"),

    # === Telephony ====
    ("call_logs", "Call Log"),
    ("web_forms", "Web Form"),
)


def _build_modified_doctype_resource(
    *,
    resource_name: str,
    doctype: str,
    base_url: str,
    api_key: str,
    api_secret: str,
    api_auth_scheme: str,
    start_date: str,
    end_date: Optional[str],
    verify: bool,
    fetch_full_docs: bool,
) -> DltResource:
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    client = FrappeClient(
        base_url=base_url,
        api_key=api_key,
        api_secret=api_secret,
        api_auth_scheme=api_auth_scheme,
        verify=verify,
    )

    @dlt.resource(
        name=resource_name,
        primary_key="name",
        write_disposition="merge",
    )
    def rows(
        modified=dlt.sources.incremental("modified", initial_value=start_date, end_value=end_date),  # type: ignore[valid-type]
    ):
        modified_start = normalize_frappe_datetime(str(modified.start_value) if modified.start_value else None)
        modified_end = normalize_frappe_datetime(str(modified.end_value) if modified.end_value else None)

        filters: list[list[Any]] = []
        if modified_start:
            filters.append(["modified", ">=", modified_start])
        if modified_end:
            filters.append(["modified", "<", modified_end])

        list_rows = client.iter_list(
            doctype=doctype,
            fields=["name", "modified"],
            filters=filters or None,
            order_by="modified asc",
            page_size=DEFAULT_PAGE_SIZE,
        )

        for row in list_rows:
            document_name = row.get("name")
            if not document_name:
                continue

            if fetch_full_docs:
                document = client.get_doc(doctype=doctype, name=str(document_name))
                if isinstance(document, dict):
                    document["_db_updated_at"] = sync_timestamp
                    yield document
                continue

            row["_db_updated_at"] = sync_timestamp
            yield row

    rows.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    rows.max_table_nesting = 0
    return rows


def build_erpnext_resources(
    *,
    base_url: str,
    api_key: str,
    api_secret: str,
    api_auth_scheme: str = "token",
    start_date: str,
    end_date: Optional[str] = None,
    verify: bool = True,
    fetch_full_docs: bool = True,
) -> tuple[DltResource, ...]:
    """Default ERPNext resources loaded into the raw layer."""

    shared_kwargs = {
        "base_url": base_url,
        "api_key": api_key,
        "api_secret": api_secret,
        "api_auth_scheme": api_auth_scheme,
        "start_date": start_date,
        "end_date": end_date,
        "verify": verify,
        "fetch_full_docs": fetch_full_docs,
    }

    return tuple(
        _build_modified_doctype_resource(
            resource_name=resource_name,
            doctype=doctype,
            **shared_kwargs,
        )
        for resource_name, doctype in SIMPLE_DOCTYPES
    )


__all__ = ["build_erpnext_resources"]
