from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

import dlt
from dlt.extract.resource import DltResource

from ingestion.frappe.client import FrappeClient, normalize_frappe_datetime

DEFAULT_PAGE_SIZE = 1000


@dataclass(frozen=True)
class ResourceSpec:
    resource_name: str
    doctype: str

    @property
    def table_name(self) -> str:
        return f"tab{self.doctype}"


RESOURCE_SPECS = (
    # === CRM Module ===
    ResourceSpec("leads", "Lead"),
    ResourceSpec("lead_products", "Lead Product"),
    ResourceSpec("regions", "Region"),
    ResourceSpec("lead_sources", "Lead Source"),
    ResourceSpec("sales_stages", "Sales Stage"),
    ResourceSpec("market_segments", "Market Segment"),
    ResourceSpec("opportunity_types", "Opportunity Type"),
    ResourceSpec("provinces", "Province"),
    ResourceSpec("opportunities", "Opportunity"),
    ResourceSpec("lead_budgets", "Lead Budget"),
    ResourceSpec("lead_demands", "Lead Demand"),
    ResourceSpec("property_setters", "Property Setter"),

    # === Core Module ===
    ResourceSpec("deleted_documents", "Deleted Document"),
    ResourceSpec("users", "User"),
    ResourceSpec("view_logs", "View Log"),
    ResourceSpec("access_logs", "Access Log"),
    ResourceSpec("files", "File"),
    ResourceSpec("comments", "Comment"),
    ResourceSpec("reports", "Report"),
    ResourceSpec("roles", "Role"),
    ResourceSpec("translations", "Translation"),
    ResourceSpec("user_permissions", "User Permission"),
    ResourceSpec("communications", "Communication"),
    ResourceSpec("role_profiles", "Role Profile"),

    # === Contact ===
    ResourceSpec("contacts", "Contact"),
    ResourceSpec("address", "Address"),

    # ==== Account ===
    ResourceSpec("payment_entries", "Payment Entry"),
    ResourceSpec("bank_accounts", "Bank Account"),
    ResourceSpec("monthly_distributions", "Monthly Distribution"),
    ResourceSpec("accounts", "Account"),
    ResourceSpec("process_subscriptions", "Process Subscription"),
    ResourceSpec("bank_transactions", "Bank Transaction"),

    # ==== Desk module ===
    ResourceSpec("todos", "ToDo"),
    ResourceSpec("tags", "Tag"),
    ResourceSpec("notification_settings", "Notification Settings"),

    # === Selling ===
    ResourceSpec("product_categories", "Product Category"),
    ResourceSpec("serials", "Serial"),
    ResourceSpec("purchase_purposes", "Purchase Purpose"),
    ResourceSpec("policies", "Policy"),
    ResourceSpec("customers", "Customer"),
    ResourceSpec("sales_orders", "Sales Order"),
    ResourceSpec("sales_order_items", "Sales Order Item"),
    ResourceSpec("promotions", "Promotion"),
    ResourceSpec("sales_partner_types", "Sales Partner Type"),
    ResourceSpec("buyback_exchanges", "Buyback Exchange"),
    ResourceSpec("promotion_groups", "Promotion Group"),
    ResourceSpec("sales_persons", "Sales Person"),
    ResourceSpec("uom_conversion_factors", "UOM Conversion Factor"),
    ResourceSpec("employees", "Employee"),
    ResourceSpec("sales_teams", "Sales Team"),


    # === Telephony ====
    ResourceSpec("call_logs", "Call Log"),
    ResourceSpec("web_forms", "Web Form"),
)


def _quote_identifier(value: str) -> str:
    return f"`{value.replace('`', '``')}`"


def _quote_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _build_incremental_query(
    *,
    spec: ResourceSpec,
    start_value: Optional[str],
    end_value: Optional[str],
    last_modified: Optional[str],
    last_name: Optional[str],
) -> str:
    table_name = _quote_identifier(spec.table_name)
    filters: list[str] = []

    if start_value is not None:
        filters.append(f"`modified` >= {_quote_literal(start_value)}")
    if end_value is not None:
        filters.append(f"`modified` < {_quote_literal(end_value)}")
    if last_modified is not None and last_name is not None:
        filters.append(
            "("
            f"`modified` > {_quote_literal(last_modified)} "
            "OR "
            f"(`modified` = {_quote_literal(last_modified)} AND `name` > {_quote_literal(last_name)})"
            ")"
        )

    where_sql = f"WHERE {' AND '.join(filters)}" if filters else ""
    return (
        f"SELECT * FROM {table_name} "
        f"{where_sql} "
        "ORDER BY `modified` ASC, `name` ASC "
        f"LIMIT {DEFAULT_PAGE_SIZE}"
    )


def _build_resource(
    *,
    spec: ResourceSpec,
    base_url: str,
    api_key: str,
    api_secret: str,
    api_auth_scheme: str,
    start_date: str,
    end_date: Optional[str],
    verify: bool,
) -> DltResource:
    client = FrappeClient(
        base_url=base_url,
        api_key=api_key,
        api_secret=api_secret,
        api_auth_scheme=api_auth_scheme,
        verify=verify,
    )
    sync_timestamp = datetime.now(timezone.utc).isoformat()

    @dlt.resource(name=spec.resource_name, primary_key="name", write_disposition="merge")
    def rows(
        modified=dlt.sources.incremental("modified", initial_value=start_date, end_value=end_date),  # type: ignore[valid-type]
    ):
        start_value = normalize_frappe_datetime(str(modified.start_value) if modified.start_value else None)
        end_value = normalize_frappe_datetime(str(modified.end_value) if modified.end_value else None)
        last_modified: Optional[str] = None
        last_name: Optional[str] = None

        while True:
            sql = _build_incremental_query(
                spec=spec,
                start_value=start_value,
                end_value=end_value,
                last_modified=last_modified,
                last_name=last_name,
            )
            batch_rows = client.execute_sql(sql)
            if not batch_rows:
                return

            for row in batch_rows:
                name = row.get("name")
                row_modified = row.get("modified")
                if name is None or row_modified is None:
                    continue

                last_name = str(name)
                last_modified = str(row_modified)
                row["_db_updated_at"] = sync_timestamp
                yield row

            if len(batch_rows) < DEFAULT_PAGE_SIZE:
                return

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
) -> tuple[DltResource, ...]:
    """Build the default ERPNext raw resources."""

    shared_kwargs = {
        "base_url": base_url,
        "api_key": api_key,
        "api_secret": api_secret,
        "api_auth_scheme": api_auth_scheme,
        "start_date": start_date,
        "end_date": end_date,
        "verify": verify,
    }

    return tuple(
        _build_resource(
            spec=spec,
            **shared_kwargs,
        )
        for spec in RESOURCE_SPECS
    )


__all__ = ["build_erpnext_resources"]
